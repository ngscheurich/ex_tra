;;; elixir-transform.el --- Region transform via elixir scripts -*- lexical-binding: t; -*-

(defvar elixir-transform-extra-bin
  (let ((elisp-dir (file-name-directory (or load-file-name buffer-file-name))))
    (expand-file-name "extra" elisp-dir))
  "Path to the `extra` binary for executing Elixir transforms.")

(defun elixir-transform-escape-region (s)
  "Escape S for embedding as a double-quoted Elixir string literal."
  (replace-regexp-in-string
   "#{" "\\#{"
   (replace-regexp-in-string
    "\"" "\\\\\""
    (replace-regexp-in-string
     "\\\\" "\\\\\\\\"
     s))))

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
  (let* ((cmd (format "%s list_transforms" elixir-transform-extra-bin))
         (raw-commands (progn (message "%s" cmd) (shell-command-to-string cmd)))
         (commands (split-string (string-trim raw-commands) ", " t)))
    (unless commands
      (user-error "No transforms found"))
    (let* ((choice (completing-read "Elixir Transform: " commands))
           (function-name choice)
           (region-str (buffer-substring-no-properties (region-beginning) (region-end)))
           (region-elixir-str (elixir-transform-escape-region region-str))
           (cmd (format "%s %s \"%s\"" elixir-transform-extra-bin function-name region-elixir-str))
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
          (when (and (fboundp 'eglot-format) (bound-and-true-p eglot--managed-mode))
            (eglot-format)))))))

(provide 'elixir-transform)
;;; elixir-transform.el ends here
