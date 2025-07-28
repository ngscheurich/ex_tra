# ExTra

Elixir Transforms for easy refactoring.

## Features

### Split Multi-Aliases

https://github.com/user-attachments/assets/94e0e76c-fd19-4754-a24e-6e54ae8a3302

### Toggle Pipeline

https://github.com/user-attachments/assets/4e28c695-f543-4c64-97d9-5137ecb0c60f

### Toggle Map Keys

https://github.com/user-attachments/assets/2f033cba-0648-41c3-9ddd-5a31c412fb7f

## Emacs

```emacs-lisp
  (use-package elixir-transform
    :bind (("C-c t t" . elixir-transform))
    :straight (elixir-transform
               :type git
               :host github
               :repo "jasonmj/ex_tra"
               :files ("emacs/**")))
```

## Vim

### Installation

Copy the entire `vim` directory into your `~/.vim/plugins/` directory, giving it the name `elixir-transform`:

```sh
cp -r vim ~/.vim/plugins/elixir-transform
```

You may need to adjust the path to the `extra` binary in your Vim configuration if it is not located in the default directory:

```vim
let g:elixir_transform_extra_bin = '~/.vim/plugins/elixir-transform/extra'
```

### Usage

- Visually select the code to transform.
- Press `<leader>tt` (default mapping) to launch the transform prompt.
- Select a transform from the prompt (populated by `extra list_transforms`).
- The transformed code will replace your selection.

## VSCode

### Installation

The ExTra extension is published on the [Open VSX Registry](https://open-vsx.org/).  
You can install it directly from there using your editor's extension manager, or with the command line:

```sh
# For VS Code (with open-vsx support) or VSCodium:
codium --install-extension jasonmj.ex_tra
```

### Usage

- Select the text you want to transform in an editor window.
- Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P` on Mac) and run the command:  
  `ExTra: Transform Selection`
- You will be prompted to choose from available transform commands, as provided by the `extra list_transforms` command.
- The selected transform will be run on your selection, and the result will replace the original code.

---

For more details or troubleshooting, see the respective `vscode/README.md` or comments inside the Vim plugin.
