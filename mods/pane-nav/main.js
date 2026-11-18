// pane-nav: ctrl+h/j/k/l that does the right thing in the Herdr app.
//
// The app routes a key to one action and cannot ask "is Vim focused?". This mod
// can: keys.json sends ctrl+h/j/k/l here (terminal section), and it either
// forwards the chord into a Vim/Neovim pane (whose own maps move between splits
// and cross out at an edge) or runs pane.go for everything else.
//
// The app delivers <mod>.<command> only to a copy that is shown, so the mod
// lives as a zero-size window overlay: `herdr-app do mod.open:pane-nav` shows
// it once, and `"keep": true` in mod.json keeps it across restarts and layouts.

import { View, div } from "gpui-kit";
import { checking, focused, hc, nextCommand, run, terminals } from "herdr";

// Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
const VIM = /^g?(view|l?n?vim?x?)(diff)?$/;

const CHORD = {
  left: "ctrl+h",
  down: "ctrl+j",
  up: "ctrl+k",
  right: "ctrl+l",
};

export default class PaneNav extends View {
  init(_props, cx) {
    if (checking()) return;
    cx.spawn(async (cx) => {
      for (;;) {
        await this.navigate(await nextCommand());
        cx.notify();
      }
    });
  }

  async navigate(command) {
    // Anything but a direction is ignored, so stray bindings are harmless.
    if (!Object.hasOwn(CHORD, command)) return;
    const terminal = focused()?.terminal;
    const name = String(terminals().find((t) => t.address === terminal)?.foreground?.name ?? "").toLowerCase();
    if (terminal && VIM.test(name)) {
      // Let the editor move between its own splits; at an edge it calls
      // `herdr-app do pane.go` itself (see editor/herdr-nav.lua).
      await hc(["keys", terminal, CHORD[command]]);
      return;
    }
    run("pane.go", { direction: command });
  }

  render() {
    // Invisible on purpose: the overlay only exists to receive key commands.
    return div();
  }
}
