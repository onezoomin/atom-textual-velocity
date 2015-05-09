h = require 'virtual-dom/h'

module.exports = (data, buses, content) ->
  { bodyHeight, topOffset, scrollTop, marginBottom, reverseStripes } = data
  { scrollTopBus } = buses

  return  h 'div', {
    className: 'tbody'
    style: height: "#{bodyHeight}px"
    onscroll: (ev) -> scrollTopBus.push(ev.srcElement.scrollTop)
  }, h 'div.tinner-body', {
      style:
        height: "#{bodyHeight}px"
        top: "#{topOffset}px"
        marginTop: "#{scrollTop}px"
        marginBottom: "#{marginBottom}px"
    }, content