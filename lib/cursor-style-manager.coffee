{Point, Disposable, CompositeDisposable} = require 'atom'
Delegato = require 'delegato'
swrap = require './selection-wrapper'

# Display cursor in visual-mode
# ----------------------------------
class CursorStyleManager
  lineHeight: null

  Delegato.includeInto(this)
  @delegatesProperty('mode', 'submode', toProperty: 'vimState')

  constructor: (@vimState) ->
    {@editorElement, @editor} = @vimState
    @disposable = atom.config.observe 'editor.lineHeight', (newValue) =>
      @lineHeight = newValue
      @refresh()

  destroy: ->
    @styleDisposables?.dispose()
    @disposable.dispose()

  refresh: ->
    # Intentionally skip in spec mode, since not all spec have DOM attached( and don't want to ).
    return if atom.inSpecMode()

    # We must dispose previous style modification for non-visual-mode
    @styleDisposables?.dispose()
    return unless (@mode is 'visual' and @vimState.getConfig('showCursorInVisualMode'))

    @styleDisposables = new CompositeDisposable
    if @submode is 'blockwise'
      cursorsToShow = @vimState.getBlockwiseSelections().map (bs) -> bs.getHeadSelection().cursor
    else
      cursorsToShow = @editor.getCursors()

    # In blockwise, show only blockwise-head cursor
    for cursor in @editor.getCursors()
      cursor.setVisible(cursor in cursorsToShow)

    # [NOTE] When activating visual-blockwise-mode multiple slections are added in bulk.
    # But corresponding cursorsComponent(HTML element) is added asynchronously.
    # We need to make sure that corresponding cursor's domNode is available to modify it's style.
    if @submode is 'blockwise'
      @editorElement.component.updateSync()

    # [NOTE] Using non-public API
    cursorNodesById = @editorElement.component.linesComponent.cursorsComponent.cursorNodesById
    for cursor in cursorsToShow when cursorNode = cursorNodesById[cursor.id]
      @styleDisposables.add @modifyStyle(cursor, cursorNode)

  getCursorBufferPositionToDisplay: (selection) ->
    bufferPosition = swrap(selection).getBufferPositionFor('head', from: ['property'])
    if @editor.hasAtomicSoftTabs() and not selection.isReversed()
      screenPosition = @editor.screenPositionForBufferPosition(bufferPosition.translate([0, +1]), clipDirection: 'forward')
      bufferPositionToDisplay = @editor.bufferPositionForScreenPosition(screenPosition).translate([0, -1])
      if bufferPositionToDisplay.isGreaterThan(bufferPosition)
        bufferPosition = bufferPositionToDisplay

    @editor.clipBufferPosition(bufferPosition)

  # Apply selection property's traversal from actual cursor to cursorNode's style
  modifyStyle: (cursor, domNode) ->
    selection = cursor.selection
    bufferPosition = @getCursorBufferPositionToDisplay(selection)

    if @submode is 'linewise' and @editor.isSoftWrapped()
      screenPosition = @editor.screenPositionForBufferPosition(bufferPosition)
      {row, column} = screenPosition.traversalFrom(cursor.getScreenPosition())
    else
      {row, column} = bufferPosition.traversalFrom(cursor.getBufferPosition())

    style = domNode.style
    style.setProperty('top', "#{row * @lineHeight}em") if row
    style.setProperty('left', "#{column}ch") if column
    new Disposable ->
      style.removeProperty('top')
      style.removeProperty('left')

module.exports = CursorStyleManager
