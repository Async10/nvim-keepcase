# nvim-keepcase

Simple search and replace while preserving the original case

<div align=center>
  <img src="./keepcase.gif">
</div>

## Features

This plugin provides the lua function `keep_case` which takes two arguments: an
original word (the word to be replaced) and a new word (the word the original
word is replaced with). `keep_case` returns the new word with the case of the
original word.

You can use the `keep_case` function together with the subsitute command to
perform a case-preserving search and replace as follows:

```
:%s/old-word/\=luaeval('keep_case(_A[1], _A[2])', [submatch(0), 'new-word'])/g
```

For convenience, the plugin provides the user command `:Replace` that does the
above operation for you. The provided range, flags, and count arguments are all
forwarded to the built-in substitute command.

## Usage

```
:%Replace/old-word/new-word/g
```

or

```
:%R/old-word/new-word/g
```

## Installation

Install using your favorite package manager, or use the built-in package
support

```bash
mkdir -p $HOME/.config/nvim/pack/vendor/start
cd $HOME/.config/nvim/pack/vendor/start
git clone https://github.com/Async10/nvim-keepcase
```

## References

This plugin is heavily inspiered by https://github.com/vim-scripts/keepcase.vim
