# ExTra

Elixir Transforms for easy refactoring.

## Emacs

```emacs-lisp
  (use-package elixir-transform
    :bind (("C-c t t" . elixir-transform))
    :straight (elixir-transform
               :type git
               :host github
               :repo "jasonmj/ex_tra"
               :files ("elixir-transform.el" "extra")))
```

