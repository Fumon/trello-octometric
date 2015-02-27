requirejs.config
  paths:
    components: 'components'
    jquery: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min'
    react: 'https://fb.me/react-0.12.2'
    d3: 'https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3'

require ['jquery', 'd3', 'react', 'components/linechart-react', 'components/histogram-react'], ($, d3, React, linechart, histogram) ->
  {div, h4, p} = React.DOM

  Graph = React.createFactory React.createClass
    displayName: 'graph'
    getInitialState: ->
      data: []
    update: (url) ->
      $.get url, ((result) ->
        data = result
        @setState {data: data}).bind(this)
    componentDidMount: ->
      @update("#{@props.urlbase}/#{@props.daysBack}")
    componentWillReceiveProps: (nextProps) ->
      @update("#{nextProps.urlbase}/#{nextProps.daysBack}")
    render: ->
      linechart
        data: @state.data
        margin:
          top: 5
          right: 30
          bottom: 50
          left: 30
        width: '100%'
        height: 300
        domainmargin: 5
        datanames: @props.datanames
        derived: @props.derived
        zeroline: @props.zeroline

  Histograph = React.createFactory React.createClass
    displayName: 'histograph'
    getInitialState: ->
      data: [] 
    update: (url) ->
      $.get url, ((result) ->
        data = result
        @setState {data: data}).bind(this)
    componentDidMount: ->
      @update("#{@props.urlbase}/#{@props.daysBack}")
    componentWillReceiveProps: (nextProps) ->
      @update("#{nextProps.urlbase}/#{nextProps.daysBack}")
    render: ->
      histogram
        data: @state.data
        margin:
          top: 5
          right: 15
          bottom: 50
          left: 30
        width: '100%'
        height: 300
        bins: 30

  TimeAdjust = React.createFactory React.createClass
    displayName: 'timeAdjust'
    update: ->
      @props.update $(@refs.timeinput.getDOMNode()).val()
    render: ->
      div {}, [
        (React.DOM.label htmlFor: "timeinput", "Days back in time"),
        (React.DOM.input
          className: "u-full-width"
          placeholder: "60"
          id: "timeinput"
          type: "text"
          ref: "timeinput"),
        (React.DOM.input
          className: "button-primary"
          value: "update"
          type: "submit"
          onClick: @update)
      ]

  Ui = React.createFactory React.createClass
    getInitialState: ->
      daysBack: 60
    updateLinechartTime: (val) ->
      parse = parseInt val
      if isNaN(parse) or parse < 1
        parse = 60
      @setState daysBack: parse
    render: ->
      div className: "section", [
        div className: "container", [
          div className: "row", [
            (h4 className: "section-heading", "Basic Daily Report"),
            (p className: "section-description",
              "This graph shows the total number of tasks on the todo board over time."),
            (Graph
              urlbase: '/api/totals/last'
              daysBack: @state.daysBack
              derived: [
                {
                  name: 'end_of_day_total'
                  func: (d) -> d.end_of_day_total
                  axis: 0
                  trendline: true
                }
              ]
            )
          ],
          div className: "row", [
            (p className: "section-description",
              "Up and finished counts per day."),
            (Graph
              urlbase: '/api/diffs/last'
              daysBack: @state.daysBack
              zeroline:
                axis: 0
              derived: [
                {
                  name: "up_count"
                  func: (d) -> d.up_count
                  axis: 0
                },
                {
                  name: "diff"
                  func: (d) -> d.up_count - d.finished_count
                  axis: 1
                  trendline: true
                },
                {
                  name: "finished_count"
                  func: (d) -> d.finished_count * -1
                  axis: 0
                }
              ]
            )
          ],
          div className: "row", [
            (p className: "section-description",
              "This graph shows how old the cards finished in this time period were."),
            (Histograph {urlbase: '/api/ages/finished/last', daysBack: @state.daysBack})
          ],
          div className: "row", [
            (TimeAdjust update: @updateLinechartTime)
          ]
        ]
      ]
      
  $ ->
    React.render (Ui {}), document.body
