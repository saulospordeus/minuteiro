import {basicSetup} from "codemirror"
import {EditorSelection, EditorState, RangeSetBuilder} from "@codemirror/state"
import {autocompletion} from "@codemirror/autocomplete"
import {defaultKeymap, history, historyKeymap} from "@codemirror/commands"
import {Decoration, EditorView, keymap, ViewPlugin, ViewUpdate} from "@codemirror/view"

const DECLARATION_REGEX = /!@[A-Za-z_][A-Za-z0-9_]*(?:\[[^\]\n]*\]|\?)?/g
const REFERENCE_REGEX = /@[A-Za-z_][A-Za-z0-9_]*/g

function templateHighlightPlugin() {
  const declarationMark = Decoration.mark({class: "cm-minuteiro-declaration"})
  const referenceMark = Decoration.mark({class: "cm-minuteiro-reference"})

  return ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.decorations = buildDecorations(view)
      }

      update(update) {
        if (update.docChanged || update.viewportChanged) {
          this.decorations = buildDecorations(update.view)
        }
      }
    },
    {
      decorations: plugin => plugin.decorations,
    },
  )

  function buildDecorations(view) {
    const builder = new RangeSetBuilder()

    for (const {from, to} of view.visibleRanges) {
      const text = view.state.doc.sliceString(from, to)
      let match
      const declarationRanges = []
      const decorationRanges = []

      DECLARATION_REGEX.lastIndex = 0
      while ((match = DECLARATION_REGEX.exec(text)) !== null) {
        const start = from + match.index
        const end = start + match[0].length

        declarationRanges.push({start, end})
        decorationRanges.push({start, end, mark: declarationMark})
      }

      REFERENCE_REGEX.lastIndex = 0
      while ((match = REFERENCE_REGEX.exec(text)) !== null) {
        const start = from + match.index
        const end = start + match[0].length

        if (!insideDeclaration(start, end, declarationRanges)) {
          decorationRanges.push({start, end, mark: referenceMark})
        }
      }

      decorationRanges
        .sort((left, right) => left.start - right.start || left.end - right.end)
        .forEach(({start, end, mark}) => {
          builder.add(start, end, mark)
        })
    }

    return builder.finish()
  }

  function insideDeclaration(start, end, declarationRanges) {
    return declarationRanges.some(range => start < range.end && end > range.start)
  }
}

function templateEditorTheme() {
  return EditorView.theme({
    "&": {
      backgroundColor: "#ffffff",
      borderRadius: "1.5rem",
      border: "1px solid color-mix(in srgb, #cbd5e1 75%, transparent)",
      minHeight: "30rem",
      overflow: "hidden",
    },
    ".cm-scroller": {
      fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
      lineHeight: "1.6",
      minHeight: "30rem",
    },
    ".cm-content": {
      color: "#0f172a",
      caretColor: "#ea580c",
      padding: "1rem",
      minHeight: "30rem",
    },
    ".cm-line": {
      padding: "0",
    },
    ".cm-focused": {
      outline: "none",
    },
    ".cm-gutters": {
      display: "none",
    },
    ".cm-cursor": {
      borderLeftColor: "#ea580c",
    },
    ".cm-selectionBackground, ::selection": {
      backgroundColor: "rgba(251, 146, 60, 0.18)",
    },
    ".cm-tooltip-autocomplete": {
      border: "1px solid rgba(203, 213, 225, 0.8)",
      borderRadius: "1rem",
      boxShadow: "0 25px 70px -40px rgba(15, 23, 42, 0.55)",
      overflow: "hidden",
      fontFamily: "inherit",
    },
    ".cm-tooltip-autocomplete > ul": {
      maxHeight: "14rem",
    },
    ".cm-tooltip-autocomplete ul li": {
      padding: "0.55rem 0.8rem",
      fontSize: "0.9rem",
    },
    ".cm-tooltip-autocomplete ul li[aria-selected]": {
      backgroundColor: "rgba(251, 146, 60, 0.14)",
      color: "#9a3412",
    },
  })
}

function variableCompletionSource(getVariableNames) {
  return context => {
    const word = context.matchBefore(/@[A-Za-z_][A-Za-z0-9_]*|@/)

    if (!word || (!context.explicit && word.from === word.to)) {
      return null
    }

    const filter = word.text.slice(1).toLowerCase()

    const options = getVariableNames()
      .filter(name => name.toLowerCase().startsWith(filter))
      .map(name => ({
        label: `@${name}`,
        type: "variable",
        apply: `@${name}`,
      }))

    if (options.length === 0 && word.text !== "@") {
      return null
    }

    return {
      from: word.from,
      options,
      validFor: /^@[A-Za-z_][A-Za-z0-9_]*?$/,
    }
  }
}

export const TemplateEditor = {
  mounted() {
    this.hiddenInput = document.getElementById(this.el.dataset.targetInputId)
    this.lastServerValue = this.el.dataset.content || ""
    this.syncTimer = null

    const completion = variableCompletionSource(() => this.variableNames())

    this.editor = new EditorView({
      state: EditorState.create({
        doc: this.lastServerValue,
        extensions: [
          basicSetup,
          history(),
          keymap.of([...defaultKeymap, ...historyKeymap]),
          templateHighlightPlugin(),
          templateEditorTheme(),
          autocompletion({override: [completion], activateOnTyping: true}),
          EditorView.lineWrapping,
          EditorView.updateListener.of(update => this.handleUpdate(update)),
        ],
      }),
      parent: this.el,
    })

    this.syncHiddenInput(this.lastServerValue)
  },

  updated() {
    const nextValue = this.el.dataset.content || ""

    if (nextValue !== this.editor.state.doc.toString()) {
      this.lastServerValue = nextValue
      this.editor.dispatch({
        changes: {from: 0, to: this.editor.state.doc.length, insert: nextValue},
        selection: EditorSelection.cursor(nextValue.length),
      })
      this.syncHiddenInput(nextValue)
    }
  },

  destroyed() {
    clearTimeout(this.syncTimer)

    if (this.editor) {
      this.editor.destroy()
    }
  },

  handleUpdate(update) {
    if (!update.docChanged) {
      return
    }

    const value = update.state.doc.toString()
    this.syncHiddenInput(value)
    clearTimeout(this.syncTimer)

    this.syncTimer = setTimeout(() => {
      this.pushEvent("editor_changed", {content: value})
    }, 150)
  },

  syncHiddenInput(value) {
    if (this.hiddenInput) {
      this.hiddenInput.value = value
    }
  },

  variableNames() {
    try {
      return JSON.parse(this.el.dataset.variableNames || "[]")
    } catch {
      return []
    }
  },
}
