{CompositeDisposable, Disposable} = require 'atom'
Bacon = require 'baconjs'
atoms = require './src/atom/streams'
setupPanel = require './src/notational/setup-panel'
notationalItems = require './src/atom/notational-items'
Path = require 'path'

module.exports =
  panel: undefined
  disposables: undefined

  config:
    bodyHeight:
      type: 'number'
      default: 200
      minimum: 0
    rowHeight:
      type: 'number'
      default: 25
      minimum: 0


  activate: (state) ->
    @disposables = new CompositeDisposable
    atomAdaptions = notationalItems()

    notationalPanel = setupPanel(
      itemsProp: atomAdaptions.itemsProp
      columnsProp: atomAdaptions.columnsProp
      bodyHeightStream: atoms.fromConfig('atom-notational.bodyHeight')
      rowHeightStream: atoms.fromConfig('atom-notational.rowHeight')
    )

    @disposableAdd atomAdaptions
    @disposableAdd notationalPanel

    # Side effects
    # Create panel 1st time the element is created
    @disposableAdd notationalPanel.elementProp.onValue (el) =>
      @panel = atom.workspace.addTopPanel(item: el) unless @panel

    # Persist resized body height
    @disposableAdd notationalPanel.resizedBodyHeightProp.debounce(500).onValue (newHeight) ->
      atom.config.set('atom-notational.bodyHeight', newHeight)

    # Handle selected item
    @disposableAdd notationalPanel.selectedItemProp.onValue (selectedItem) ->
      # TODO: preview selected item

    # TODO: move sampleBy inside panel?
    @disposableAdd notationalPanel.selectedItemProp.sampledBy(notationalPanel.openSelectedStream).onValue (selectedItem) ->
      if selectedItem
        atom.workspace.open Path.join(selectedItem.projectPath, selectedItem.relPath)

    # Handle panel
    @disposables.add atom.commands.add 'atom-workspace', 'atom-notational:toggle-panel', =>
      if @panel.isVisible()
        @panel.hide()
      else
        @panel.show()
        @panel.getItem().querySelector('.search').focus()

    @disposables.add atom.commands.add 'atom-workspace', 'atom-notational:focus', =>
      @panel.show() unless @panel.isVisible()
      @panel.getItem().querySelector('.search').focus()


  disposableAdd: (disposalAction) ->
    @disposables.add new Disposable(disposalAction)


  deactivate: ->
    @disposables.dispose()
    @panel?.destroy()
    @panel = null
