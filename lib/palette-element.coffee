{CompositeDisposable} = require 'atom'
{SpacePenDSL, EventsDelegation} = require 'atom-utils'
pigments = require './pigments'
Palette = require './palette'

class PaletteElement extends HTMLElement
  SpacePenDSL.includeInto(this)
  EventsDelegation.includeInto(this)

  @content: ->
    sort = atom.config.get('pigments.sortPaletteColors')
    group = atom.config.get('pigments.groupPaletteColors')
    optAttrs = (selected, attrs) ->
      attrs.selected = 'selected' if selected
      attrs

    @div class: 'palette-panel', =>
      @div class: 'palette-controls', =>
        @div class: 'palette-controls-wrapper', =>
          @span class: 'input-group-inline', =>
            @label for: 'sort-palette-colors', 'Sort Colors'
            @select outlet: 'sort', id: 'sort-palette-colors', =>
              @option optAttrs(sort is 'none', value: 'none'), 'None'
              @option optAttrs(sort is 'by name', value: 'by name'), 'By Name'
              @option optAttrs(sort is 'by file', value: 'by color'), 'By Color'

          @span class: 'input-group-inline', =>
            @label for: 'sort-palette-colors', 'Group Colors'
            @select outlet: 'group', id: 'group-palette-colors', =>
              @option optAttrs(group is 'none', value: 'none'), 'None'
              @option optAttrs(group is 'by file',  value: 'by file'), 'By File'

      @div class: 'palette-list', =>
        @ol outlet: 'list'

  createdCallback: ->
    @project = pigments.getProject()
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.observe 'pigments.sortPaletteColors', (@sortPaletteColors) =>
      @renderList() if @palette? and @attached

    @subscriptions.add atom.config.observe 'pigments.groupPaletteColors', (@groupPaletteColors) =>
      @renderList() if @palette? and @attached

    @subscriptions.add @subscribeTo @sort, 'change': (e) ->
      atom.config.set 'pigments.sortPaletteColors', e.target.value

    @subscriptions.add @subscribeTo @group, 'change': (e) ->
      atom.config.set 'pigments.groupPaletteColors', e.target.value

  attachedCallback: ->
    @renderList() if @palette?
    @attached = true

  getTitle: -> 'Palette'

  getURI: -> 'pigments://palette'

  getIconName: -> "pigments"

  getModel: -> @palette

  setModel: (@palette) -> @renderList() if @attached

  getColorsList: (palette) ->
    switch @sortPaletteColors
      when 'by color' then palette.sortedByColor()
      when 'by name' then palette.sortedByName()
      else palette.tuple()

  renderList: ->
    @stickyTitle?.dispose()
    @list.innerHTML = ''

    if @groupPaletteColors is 'by file'
      palettes = @getFilesPalettes()
      for file, palette of palettes
        li = document.createElement('li')
        li.className = 'color-group'
        ol = document.createElement('ol')

        li.appendChild @getGroupHeader(file)
        li.appendChild ol
        @buildList(ol, @getColorsList(palette))
        @list.appendChild(li)

      @stickyTitle = new StickyTitle(
        @list.querySelectorAll('.color-group-header-content'),
        @querySelector('.palette-list')
      )
    else
      @buildList(@list, @getColorsList(@palette))

  getGroupHeader: (label) ->
    header = document.createElement('div')
    header.className = 'color-group-header'

    content = document.createElement('div')
    content.className = 'color-group-header-content'
    content.textContent = label

    header.appendChild(content)
    header

  getFilesPalettes: ->
    palettes = {}

    @palette.eachColor (name, color) =>
      {path} = @project.getVariableByName(name)

      palettes[path] ?= new Palette
      palettes[path].colors[name] = color

    palettes

  buildList: (container, paletteColors) ->
    for [name, color] in paletteColors
      li = document.createElement('li')
      li.className = 'color-item'
      html = """
      <span class="pigments-color"
            style="background-color: #{color.toCSS()}">
      </span>
      <span class="pigments-color-details">
        <span class="color-entry">
          <span class="name">#{name}</span>
      """
      if variable = @project.getVariableByName(name)
        html += """
        <span class="path">#{atom.project.relativize(variable.path)}</span>
        """

      html += '</span></span>'

      li.innerHTML = html

      container.appendChild(li)

module.exports = PaletteElement =
document.registerElement 'pigments-palette', {
  prototype: PaletteElement.prototype
}

PaletteElement.registerViewProvider = (modelClass) ->
  atom.views.addViewProvider modelClass, (model) ->
    element = new PaletteElement
    element.setModel(model)
    element

class StickyTitle
  EventsDelegation.includeInto(this)

  constructor: (@stickies, @scrollContainer) ->
    @subscriptions = new CompositeDisposable
    Array::forEach.call @stickies, (sticky) ->
      sticky.parentNode.style.height = sticky.offsetHeight + 'px'
      sticky.style.width = sticky.offsetWidth + 'px'

    @subscriptions.add @subscribeTo @scrollContainer, 'scroll': (e) =>
      @scroll(e)

  dispose: ->
    @subscriptions.dispose()
    @stickies = null
    @scrollContainer = null

  scroll: (e) ->
    delta = if @lastScrollTop
      @lastScrollTop - @scrollContainer.scrollTop
    else
      0

    Array::forEach.call @stickies, (sticky, i) =>
      nextSticky = @stickies[i + 1]
      prevSticky = @stickies[i - 1]
      scrollTop = @scrollContainer.getBoundingClientRect().top
      parentTop = sticky.parentNode.getBoundingClientRect().top
      {top} = sticky.getBoundingClientRect()

      if parentTop < scrollTop
        unless sticky.classList.contains('absolute')
          sticky.classList.add 'fixed'
          sticky.style.top = scrollTop + 'px'

          if nextSticky?
            nextTop = nextSticky.parentNode.getBoundingClientRect().top
            if top + sticky.offsetHeight >= nextTop
              sticky.classList.add('absolute')
              sticky.style.top = @scrollContainer.scrollTop + 'px'

      else
        sticky.classList.remove 'fixed'

        if prevSticky? and prevSticky.classList.contains('absolute')
          prevTop = prevSticky.getBoundingClientRect().top
          prevTop -= prevSticky.offsetHeight if delta < 0

          if scrollTop <= prevTop
            prevSticky.classList.remove('absolute')
            prevSticky.style.top = scrollTop + 'px'

    @lastScrollTop = @scrollContainer.scrollTop
