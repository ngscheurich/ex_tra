;;; elixir-transform.el --- Region transform via elixir scripts -*- lexical-binding: t; -*-

(defvar elixir-transform-extra-bin
  (let ((elisp-dir (file-name-directory (or load-file-name buffer-file-name))))
    (expand-file-name "extra" elisp-dir))
  "Path to the `extra` binary for executing Elixir transforms.")

(defvar elixir-transform-tools-dir
  (let ((elisp-dir (file-name-directory (or load-file-name buffer-file-name))))
    (expand-file-name "lib/tools" elisp-dir))
  "Path to the directory containing Elixir transformation scripts.")

;; List available transforms
(defun elixir-transform--list-scripts ()
  "Return list of (filepath . function-name) pairs in elixir_transforms at the project root."
  (let* ((dir elixir-transform-tools-dir)
         (scripts (and (file-directory-p dir)
                       (directory-files dir t "\\.ex$"))))
    (when scripts
      (mapcar (lambda (f)
                (cons f (file-name-base f)))
              scripts))))

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
      (user-error "No transforms found"))
    (let* ((choice (completing-read "Elixir transform: " (mapcar #'cdr scripts)))
           (script-pair (assoc-default choice (mapcar (lambda (pr) (cons (cdr pr) pr)) scripts)))
           (script-path (car script-pair))
           (function-name (cdr script-pair))
           (region-str (buffer-substring-no-properties (region-beginning) (region-end)))
           (region-elixir-str (elixir-transform-escape-region region-str))
           (cmd (format "%s %s %s" elixir-transform-extra-bin function-name region-elixir-str))
           (start (region-beginning))
           (end (region-end))
           (orig-buf (current-buffer))
           (raw-output (shell-command-to-string cmd))
           (clean-output (elixir-transform-clean-string (string-trim raw-output))))
      (with-current-buffer orig-buf
        (atomic-change-group
          (delete-region start end)
          (goto-char start)
          (insert clean-output)
          (eglot-format))))))

(provide 'elixir-transform)
;;; elixir-transform.el ends here
