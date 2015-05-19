Bacon = require 'baconjs'
renderRoot = require '../vdom/root.coffee'
columns = require '../columns.coffee'
navArray = require '../navigate_array.coffee'
selectedScrollTop = require './selected-scroll-top.coffee'

module.exports = ({ bodyHeightStream, rowHeightStream, addItemsStream, removeItemsStream, removedProjectStream, moveSelectedStream}, buses) ->
  {scrollTopBus, searchBus, selectedItemBus} = buses
  rowHeightProp = rowHeightStream.toProperty()
  bodyHeightProp = bodyHeightStream
    .skipDuplicates()
    .filter (height) -> height > 0
    .toProperty()

  itemsProp = Bacon.update [],
    [addItemsStream], (items, newItem) ->
      items.concat(newItem)
    [removeItemsStream], (items, { relPath }) ->
      items.filter (item) ->
        item.relPath isnt relPath
    [removedProjectStream], (items, removedPath) ->
      items.filter ({ projectPath }) ->
        projectPath isnt removedPath

  matchedItemsProp = Bacon.combineWith (items, searchStr) ->
    if searchStr
      items.filter (item) ->
        item.relPath.toLowerCase().search(searchStr) isnt -1
    else
      items
  , itemsProp, searchBus.toProperty('')

  selectedItemProp = Bacon.update false,
    [selectedItemBus], (currentItem, item) -> item
    [moveSelectedStream, matchedItemsProp], (currentItem, relativeOffset, items) ->
      selectedItemBus.push if currentItem
                             navArray.byRelativeOffset items, relativeOffset, (item) -> currentItem is item
                           else if relativeOffset < 0
                             NavigateArray.byOffset(items, -1)
                           else
                             items[0]

  selectedScrollTopProp = selectedScrollTop(
    matchingItemsProp: matchedItemsProp
    selectedItemProp: selectedItemBus.toProperty(false)
    rowHeightProp: rowHeightProp
    scrollTopProp: scrollTopBus.toProperty(0)
    bodyHeightProp: bodyHeightProp
  )
  scrollTopProp = Bacon.update 0,
    [scrollTopBus], (prev, scrollTop) -> scrollTop
    [selectedItemBus, selectedScrollTopProp], (prev, selectedItem, scrollTop) -> scrollTop

  visibleBeginProp = Bacon.combineWith (scrollTop, rowHeight) ->
    (scrollTop / rowHeight) | 0
  , scrollTopProp, rowHeightProp
  visibleEndProp = Bacon.combineWith (begin, bodyHeight, rowHeight) ->
    begin + ((bodyHeight / rowHeight) | 0) + 2 # add to avoid visible gap when scrolling
  , visibleBeginProp, bodyHeightProp, rowHeightProp

  return Bacon.combineWith (data, _) ->
      renderRoot(data, columns, buses)
    , Bacon.combineTemplate {
      selectedItem: selectedItemProp
      bodyHeight: bodyHeightProp
      rowHeight: rowHeightProp
      scrollTop: scrollTopProp

      topOffset: Bacon.combineWith (scrollTop, rowHeight) ->
        -(scrollTop % rowHeight)
      , scrollTopProp, rowHeightProp

      marginBottom: Bacon.combineWith (items, rowHeight, scrollTop, bodyHeight) ->
        items.length * rowHeight - scrollTop - bodyHeight
      , matchedItemsProp, rowHeightProp, scrollTopProp, bodyHeightProp

      reverseStripes: visibleBeginProp.map (begin) -> begin % 2 is 0

      items: Bacon.combineWith (items, begin, end) ->
        items.slice(begin, end)
      , matchedItemsProp, visibleBeginProp, visibleEndProp
    }#, Bacon.interval(1000, undefined)
