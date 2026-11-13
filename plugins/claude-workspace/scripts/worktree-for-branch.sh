#!/usr/bin/env bash
# worktree-for-branch.sh <root> <branch>
# Prints the path of a linked worktree that holds <branch>, or nothing.
git -C "$1" worktree list --porcelain | awk -v b="refs/heads/$2" '/^worktree /{n++; p=substr($0,10)} n>1 && $0=="branch " b {print p}'
