fs = require 'fs-plus'
path = require 'path'
{TextEditor} = require 'atom'
Minimap = require '../lib/minimap'
MinimapElement = require '../lib/minimap-element'

stylesheetPath = path.resolve __dirname, '..', 'stylesheets', 'minimap.less'
stylesheet = atom.themes.loadStylesheet(stylesheetPath)

describe 'MinimapElement', ->
  [editor, minimap, largeSample, smallSample, jasmineContent, editorElement, minimapElement] = []

  beforeEach ->
    atom.config.set 'minimap.charHeight', 4
    atom.config.set 'minimap.charWidth', 2
    atom.config.set 'minimap.interline', 1

    MinimapElement.registerViewProvider()

    editor = new TextEditor({})
    editor.setLineHeightInPixels(10)
    editor.setHeight(50)

    minimap = new Minimap({textEditor: editor})
    largeSample = fs.readFileSync(atom.project.resolve('large-file.coffee')).toString()
    smallSample = fs.readFileSync(atom.project.resolve('sample.coffee')).toString()

    editor.setText largeSample

    editorElement = atom.views.getView(editor)
    minimapElement = atom.views.getView(minimap)

  it 'has been registered in the view registry', ->
    expect(minimapElement).toExist()

  it 'has stored the minimap as its model', ->
    expect(minimapElement.getModel()).toBe(minimap)

  it 'has a canvas in a shadow DOM', ->
    expect(minimapElement.shadowRoot.querySelector('canvas')).toExist()

  it 'has a div representing the visible area', ->
    expect(minimapElement.shadowRoot.querySelector('.minimap-visible-area')).toExist()

  describe 'when attached to the text editor element', ->
    [nextAnimationFrame, canvas, visibleArea] = []

    beforeEach ->
      jasmineContent = document.body.querySelector('#jasmine-content')

      spyOn(window, "setInterval").andCallFake window.fakeSetInterval
      spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

      noAnimationFrame = -> throw new Error('No animation frame requested')
      nextAnimationFrame = noAnimationFrame

      requestAnimationFrameSafe = window.requestAnimationFrame
      spyOn(window, 'requestAnimationFrame').andCallFake (fn) ->
        nextAnimationFrame = ->
          nextAnimationFrame = noAnimationFrame
          fn()

      styleNode = document.createElement('style')
      styleNode.textContent = """
        #{stylesheet}

        atom-text-editor atom-text-editor-minimap, atom-text-editor::shadow atom-text-editor-minimap {
          background: rgba(255,0,0,0.3);
        }

        atom-text-editor atom-text-editor-minimap::shadow .minimap-visible-area, atom-text-editor::shadow atom-text-editor-minimap::shadow .minimap-visible-area {
          background: rgba(0,255,0,0.3);
        }
      """

      jasmineContent.appendChild(styleNode)

    beforeEach ->
      canvas = minimapElement.shadowRoot.querySelector('canvas')
      editorElement.style.width = '200px'
      editorElement.style.height = '50px'

      jasmineContent.appendChild(editorElement)
      editor.setScrollTop(1000)
      editor.setScrollLeft(200)
      minimapElement.attach()

    it 'takes the height of the editor', ->
      expect(minimapElement.offsetHeight).toEqual(editorElement.clientHeight)

      # Actually, when in a flex display of 200px width, 10% gives 18px
      # and not 20px
      expect(minimapElement.offsetWidth).toBeCloseTo(editorElement.clientWidth / 10, -1)

    it 'resizes the canvas to fit the minimap', ->
      expect(canvas.offsetHeight).toEqual(minimapElement.offsetHeight + minimap.getLineHeight())
      expect(canvas.offsetWidth).toEqual(minimapElement.offsetWidth)

    it 'requests an update', ->
      expect(minimapElement.frameRequested).toBeTruthy()

    describe 'when the update is performed', ->
      beforeEach ->
        nextAnimationFrame()
        visibleArea = minimapElement.shadowRoot.querySelector('.minimap-visible-area')

      it 'sets the visible area width and height', ->
        expect(visibleArea.offsetWidth).toEqual(minimapElement.clientWidth)
        expect(visibleArea.offsetHeight).toBeCloseTo(minimap.getTextEditorHeight(), 0)

      it 'sets the visible visible area offset', ->
        expect(visibleArea.offsetTop).toBeCloseTo(minimap.getTextEditorScrollTop() - minimap.getMinimapScrollTop(), 0)
        expect(visibleArea.offsetLeft).toBeCloseTo(minimap.getTextEditorScrollLeft(), 0)

      it 'offsets the canvas when the scroll does not match line height', ->
        editor.setScrollTop(1004)
        nextAnimationFrame()

        expect(canvas.offsetTop).toEqual(-2)

      describe 'when the editor is scrolled', ->
        beforeEach ->
          editor.setScrollTop(2000)
          editor.setScrollLeft(50)

          nextAnimationFrame()

        it 'updates the visible area', ->
          expect(visibleArea.offsetTop).toBeCloseTo(minimap.getTextEditorScrollTop() - minimap.getMinimapScrollTop(), 0)
          expect(visibleArea.offsetLeft).toBeCloseTo(minimap.getTextEditorScrollLeft(), 0)
