Bacon = require 'baconjs'
createElement = require 'virtual-dom/create-element'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
renderRoot = require './virtual-dom/root'
calcs = require './prop-calculations'
moment = require("moment")

fromAtomConfig = (settingName) ->
  Bacon.fromBinder (sink) ->
    disposable = atom.config.observe "atom-notational.#{settingName}", sink
    return -> disposable.dispose()

module.exports =
  panel: undefined
  rootNode: undefined
  prevTree: undefined

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
    # Source streams
    rowHeightStream = fromAtomConfig('rowHeight')
    bodyHeightStream = fromAtomConfig('bodyHeight')
    scrollTopBus = new Bacon.Bus()
    bodyHeightBus = new Bacon.Bus()

    # Application props
    columns = Bacon.constant [{
      title: 'Name'
      width: 60
      cellContent: (item) -> item.title
    },{
      title: 'Date created'
      width: 20
      cellContent: (item) -> moment(item.dateCreated).fromNow()
    },{
      title: 'Date modified'
      width: 20
      cellContent: (item) -> moment(item.dateModified).fromNow()
    }]
    matchingItemsProp = Bacon.constant(for i in [1..100]
      {
        title: "item #{i}"
        dateCreated:  new Date
        dateModified: new Date
      })
    scrollTopProp = scrollTopBus.toProperty(0)
    rowHeightProp = rowHeightStream.toProperty()
    bodyHeightProp = bodyHeightStream
      .merge(bodyHeightBus)
      .skipDuplicates()
      .filter (height) -> height > 0
      .toProperty()
    visibleBeginProp = Bacon.combineWith(calcs.visibleBeginOffset, scrollTopProp, rowHeightProp)
    visibleEndProp = Bacon.combineWith(calcs.visibleEndOffset, visibleBeginProp, bodyHeightProp, rowHeightProp)
    topOffsetProp = Bacon.combineWith(calcs.topOffset, scrollTopProp, rowHeightProp)
    marginBottomProp = Bacon.combineWith(calcs.marginBottom, matchingItemsProp, rowHeightProp, scrollTopProp, bodyHeightProp)
    visibleItemsProp = Bacon.combineWith(calcs.visibleItems, matchingItemsProp, visibleBeginProp, visibleEndProp)
    reverseStripesProp = visibleBeginProp.map (begin) -> begin % 2 == 0

    dataProp = Bacon.combineTemplate {
      items: visibleItemsProp
      bodyHeight: bodyHeightProp
      rowHeight: rowHeightProp
      scrollTop: scrollTopProp
      topOffset: topOffsetProp
      reverseStripes: reverseStripesProp
      marginBottom: marginBottomProp
      columns: columns
    }
    renderedTreeProp = Bacon.combineWith (data) ->
      renderRoot data, {
        scrollTopBus: scrollTopBus
        bodyHeightBus: bodyHeightBus
      }
    , dataProp, Bacon.interval(1000, undefined)

    # Side effects, re-render
    renderedTreeProp.onValue (newTree) =>
      if @rootNode
        @rootNode = patch(@rootNode, diff(@prevTree, newTree))
      else
        @rootNode = createElement(newTree)
        @panel = atom.workspace.addTopPanel {
          item: @rootNode
        }
      @prevTree = newTree

    # Persist new height
    bodyHeightBus.debounce(500).onValue (newHeight) ->
      atom.config.set('atom-notational.bodyHeight', newHeight)

  deactivate: ->
    @panel?.destroy()
    @prevTree = null
    @rootNode = null
