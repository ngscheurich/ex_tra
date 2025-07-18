;;; elixir-transform.el --- Region transform via elixir scripts -*- lexical-binding: t; -*-

;; List available transforms
(defun elixir-transform--list-scripts ()
  "Return list of (filepath . function-name) pairs in elixir_transforms at the project root."
  (let* ((project (project-current t))
         (proj-root (if project (project-root project) default-directory))
         (dir (expand-file-name "elixir_transforms" proj-root))
         (scripts (and (file-directory-p dir)
                       (directory-files dir t "\.exs$"))))
    (when scripts
      (mapcar (lambda (f)
                (cons f (file-name-base f)))
              scripts))))

;; Send command to IEx and get the output
(defun elixir-transform--send-to-iex (command)
  "Send COMMAND to the current project's IEx shell and return the output as string.
Uses unique delimiters to mark output boundaries."
  (message "%s" command)
  (let* ((project (project-current t))
         (default-directory (if project (project-root project) default-directory))
         (shell-buf (or (get-buffer "*shell*")
                        (and (fboundp 'project-shell)
                             (get-buffer (format "*shell*<%s>" (project-name project)))))))
    (unless (and shell-buf (buffer-live-p shell-buf))
      (setq shell-buf (if (fboundp 'project-shell)
                          (project-shell)
                        (shell "*shell*"))))
    (let* ((start-marker (format "~elixir-transform-%s~" (md5 (number-to-string (float-time)))))
           (end-marker   (format "~elixir-transform-end-%s~" (md5 (number-to-string (+ (float-time) 100000)))))
           (full-cmd (format "IO.puts(%S)\n%s\nIO.puts(%S)\n"
                             start-marker
                             command
                             end-marker))
           (output ""))
      (with-current-buffer shell-buf
        (goto-char (point-max))
        (let ((comint-move-point-for-output nil))
          (comint-send-string shell-buf full-cmd))
        (let ((start nil)
              (end nil)
              (wait-limit 100) ; ~3s
              (tick 0))
          (while (and (not end) (< tick wait-limit))
            (accept-process-output nil 0.03)
            (setq output (buffer-substring-no-properties (point-min) (point-max)))
            (setq start (string-match (regexp-quote start-marker) output start))
            (setq end (and start (string-match (regexp-quote end-marker) output (1+ start))))
            (cl-incf tick))
          (if (and start end)
              (string-trim (substring output (+ start (length start-marker)) end))
            (user-error "elixir-transform: Did not find output boundaries in shell buffer!")))))))

;; Parse {:ok, result} | {:error, reason} from output
(defun elixir-transform--parse-elixir-result (output)
  "Parse {:ok, result} or {:error, reason} tuple from OUTPUT, searching all lines.
Returns (ok RESULT) or (error REASON), or signals an error if parsing fails."
  (let* ((lines (split-string output "\n" t))
         (tuple-info
          (seq-find
           (lambda (l)
             (or (string-match "{:ok,\\s-*\\(.+\\)}" l)
                 (string-match "{:error,\\s-*\\(.+\\)}" l)))
           lines)))
    (cond
     ((and tuple-info (string-match "{:ok,\\s-*\\(.+\\)}" tuple-info))
      (let ((raw-result (match-string 1 tuple-info)))
        (list 'ok (elixir-transform-clean-string raw-result))))
     ((and tuple-info (string-match "{:error,\\s-*\\(.+\\)}" tuple-info))
      (list 'error (elixir-transform-clean-string (match-string 1 tuple-info))))
     (t
      (list 'error (format "Error: %s" output))))))

(defun elixir-transform-escape-region (s)
  "Escape S for embedding as a double-quoted Elixir string literal, per https://hexdocs.pm/elixir/String.html#module-escape-characters."
  (let* ((table '(("\"" . "\\\"")
                  ("\\" . "\\\\")
                  ("\n" . "\\n")
                  ("\t" . "\\t")
                  ("\r" . "\\r")
                  ("\v" . "\\v")
                  ("\b" . "\\b")
                  ("\f" . "\\f")))
         (escaped (replace-regexp-in-string
                   "[\"\\\n\t\r\v\b\f]"
                   (lambda (m) (cdr (assoc m table)))
                   s t t)))
    (setq escaped (replace-regexp-in-string "#{" "\\#{" escaped t t))
    (format "\"%s\"" escaped)))

(defun elixir-transform-clean-string (input)
  "Cleans INPUT by replacing escaped characters, trimming leading newlines, and removing surrounding quotes."
  (replace-regexp-in-string
   "^\"\\|\"$" ""
   (replace-regexp-in-string
    "\\\\#{" "#{"
    (replace-regexp-in-string
     "\\\\\"" "\""
     (replace-regexp-in-string "\\\\n" "\n" input)))))

;;;###autoload
(defun elixir-transform ()
  "Interactively select an Elixir transform and apply it to the selected region."
  (interactive)
  (unless (use-region-p)
    (user-error "No active region"))
  (let* ((scripts (elixir-transform--list-scripts)))
    (unless scripts
      (user-error "No Elixir transforms found in ./elixir_transforms"))
    (let* ((choice (completing-read "Elixir transform: " (mapcar #'cdr scripts)))
           (script-pair (assoc-default choice (mapcar (lambda (pr) (cons (cdr pr) pr)) scripts)))
           (script-path (car script-pair))
           (function-name (cdr script-pair))
           (module-name (mapconcat 'capitalize (split-string function-name "_") ""))
           (region-str (buffer-substring-no-properties (region-beginning) (region-end)))
           (region-elixir-str (elixir-transform-escape-region region-str))
           (cmd (format "%s.%s(%s) |> then(& if is_binary(&1), do: &1, else: inspect(&1)) |> IO.puts()"
                        module-name
                        function-name
                        region-elixir-str))
           (start (region-beginning))
           (end (region-end))
           (orig-buf (current-buffer))
           (output (progn
                     (elixir-transform--send-to-iex (format "_ = Code.unrequire_files([%S])\n_ = Code.require_file(%S)\n" script-path script-path))
                     (save-current-buffer
                       (elixir-transform--send-to-iex cmd))))
           (parsed (elixir-transform--parse-elixir-result output)))
      (pcase parsed
        (`(ok ,result)
         ;;(clear-shell-buffer-to-last-prompt)
         (with-current-buffer orig-buf
           (atomic-change-group
             (delete-region start end)
             (goto-char start)
             (insert result)
             (delete-window)
             (eglot-format))))
        (`(error ,reason)
         (user-error "Elixir transform failed: %s" reason))))))

(provide 'elixir-transform)
;;; elixir-transform.el ends here
