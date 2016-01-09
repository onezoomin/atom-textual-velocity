'use babel'

import React from 'react-for-atom'
import Bacon from 'baconjs'
import R from 'ramda'
import classNames from 'classnames'
import Search from './search'
import ScrollableContent from './scrollable-content'
import ResizeHandle from './resize-handle'
import Th from './th'
import Item from './item'
import Summary from './cells/summary'
import DateTime from './cells/date-time'
import BaconMixin from './baconjs-mixin'

export default React.createClass({

  mixins: [BaconMixin],

  propTypes: {
    bodyHeightStream: React.PropTypes.object,
    showStream: React.PropTypes.object,
    resultsProp: React.PropTypes.object
  },

  getInitialState () {
    return {
      rowHeight: 25,
      bodyHeight: 100,
      scrollTop: 0,
      // TODO mapped version of titles, calculated widths, createCell
      columns: [
        {
          title: 'Name',
          width: 70,
          createCell: (item, r) => <Summary key='name' item={item} results={r} />
        }, {
          title: 'Date modified',
          width: 15,
          createCell: item => <DateTime key='mtime' time={item.stat.mtime} />
        }, {
          title: 'Date created',
          width: 15,
          createCell: item => <DateTime key='birhtime' time={item.stat.birthtime} />
        }
      ],
      results: {
        offset: 0,
        total: 0,
        items: []
      },
      selectedIndex: null
    }
  },

  componentWillMount () {
    let selectIndexBus = new Bacon.Bus()
    let changeBus = new Bacon.Bus()
    let keyDownBus = new Bacon.Bus()
    let bodyHeightBus = new Bacon.Bus()

    let resetStream = keyDownBus.filter(R.propEq('keyCode', 27)).map('') // <esc>
    let searchStream = changeBus.map('.target.value').merge(resetStream)
    let searchProp = searchStream.toProperty('')

    bodyHeightBus.plug(this.props.bodyHeightStream)
    let bodyHeightProp = bodyHeightBus.skipDuplicates().filter(newHeight => newHeight > 0).toProperty(100)

    let selectPrevStream = keyDownBus.filter(R.propEq('keyCode', 38)).doAction('.preventDefault') // <up>
    let selectNextStream = keyDownBus.filter(R.propEq('keyCode', 40)).doAction('.preventDefault') // <down>

    let selectedIndexProp = Bacon.update(
      null,
      [searchStream], R.always(null),
      [selectIndexBus], R.nthArg(-1),
      [selectPrevStream, this.props.resultsProp], (currentIndex, _, results) => {
        // Select prev item; cycle back to last item if current is the first item
        const newIndex = (currentIndex || results.total) - 1
        return newIndex >= 0
          ? newIndex
          : currentIndex
      },
      [selectNextStream, this.props.resultsProp], (currentIndex, _, results) => {
        // Select next item; stop at last item
        const newIndex = R.defaultTo(-1, currentIndex) + 1
        return newIndex < results.total
          ? newIndex
          : currentIndex
      }
    ).skipDuplicates()

    let scrollTopBus = new Bacon.Bus()
    let scrollTopProp = Bacon.update(
      0,
      [scrollTopBus], R.nthArg(-1),
      [searchStream], R.always(0),
      [selectedIndexProp.filter(R.is(Number)).changes()], (scrollTop, index) => {
        // Adjust scrollTop for selected item
        let selectedScrollTop = index * this.state.rowHeight
        if (scrollTop > selectedScrollTop) {
          // selected item is located before the visible bounds
          // from: ..X..[...]..
          // to:   .[X..]......
          return selectedScrollTop
        } else if (scrollTop + this.state.bodyHeight <= selectedScrollTop) {
          // selected item is located after the visible bounds
          // from: ..[...]..X..
          // to:   ......[..X].
          return selectedScrollTop - this.state.bodyHeight + this.state.rowHeight
        } else {
          // selected item is located within the visible bounds, just return the current scrollTop value
          return scrollTop
        }
      }
    )

    this.onStreamsValues(
      bodyHeightProp, scrollTopProp, searchProp, selectedIndexProp, this.props.resultsProp,
      (bodyHeight, scrollTop, searchStr, selectedIndex, results) => {
        this.setState({
          bodyHeight: bodyHeight,
          scrollTop: scrollTop,
          results: results,
          selectedIndex: selectedIndex
        })
      }
    )

    // expose some observables for sub-components
    this._searchStream = searchStream
    this._keyDownBus = keyDownBus
    this._changeBus = changeBus
    this._selectIndexBus = selectIndexBus
    this._scrollTopBus = scrollTopBus
    this._bodyHeightBus = bodyHeightBus
    this._focusBus = new Bacon.Bus()
    this._focusBus.plug(this.props.showStream)

    // also expose some observables for caller (to assign side-effects outside of this scope)
    const calcPagination = R.curry(val => (val / this.state.rowHeight) | 0)
    this.paginationOffsetProp = scrollTopProp.map(calcPagination)
    this.paginationSizeProp = bodyHeightProp.map(R.pipe(calcPagination, R.add(2)))
    this.openStream = keyDownBus.filter(R.propEq('keyCode', 13)) // <enter>
    this.resetStream = resetStream
    this.bodyHeightProp = bodyHeightProp
    this.searchProp = searchProp

    this.selectedItemProp = Bacon
      .combineWith(this.props.resultsProp, selectedIndexProp, (r, index) => r.items[index])
      .filter(R.is(Object))
  },

  render () {
    const r = this.state.results
    return (
      <div className='notational'>
        <Search showStream={this.props.showStream.merge(this._focusBus)}
            searchStream={this._searchStream}
            keyDownBus={this._keyDownBus}
            changeBus={this._changeBus}
          />
        <div className='notational-items'>
          <div className='header'>
            <table>
              <thead>
                <tr>
                  {this.state.columns.map((c) =>
                    <Th key={c.title} width={c.width + '%'} title={c.title} />
                  )}
                </tr>
              </thead>
            </table>
          </div>
          <ScrollableContent focusBus={this._focusBus}
              bodyHeight={this.state.bodyHeight} rowHeight={this.state.rowHeight}
              resultsTotal={r.total} resultsOffset={r.offset}
              scrollTop={this.state.scrollTop} scrollTopBus={this._scrollTopBus}>
            <table>
              <thead className='only-for-column-widths'>
                <tr>
                  {this.state.columns.map(c =>
                    <Th key={c.title} width={c.width + '%'} title='' />
                  )}
                </tr>
              </thead>
              <tbody className={classNames({'is-reversed-stripes': r.offset % 2 === 1})}>
                {r.items.map((item, i) => {
                  const index = r.offset + i
                  return (
                    <Item key={item.hrtime} item={item} isSelected={index === this.state.selectedIndex}
                        index={index} selectIndexBus={this._selectIndexBus}>
                      {this.state.columns.map(c => c.createCell(item, r))}
                    </Item>
                  )
                })}
              </tbody>
            </table>
          </ScrollableContent>
          <ResizeHandle bodyHeight={this.state.bodyHeight} bodyHeightBus={this._bodyHeightBus} />
        </div>
      </div>
    )
  }

})