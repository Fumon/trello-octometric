requirejs.config
  paths:
    components: 'components'
    calheatmap: '../libs/cal-heatmap.min'
    jquery: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min'
    react: 'https://fb.me/react-0.12.2'
    d3: 'https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3'

require ['jquery', 'd3', 'react', 'components/linechart-react',
  'components/heatmap-react'], ($, d3, React, linechart, heatmap) ->
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
          right: 15
          bottom: 50
          left: 30
        width: '100%'
        height: 300
        domainmargin: 20
        datanames: @props.datanames

  Heatmap = React.createFactory React.createClass
    displayName: 'heatmap'
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
      heatmap
        data: @state.data
        datanames: @props.datanames

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
            (Graph {urlbase: '/api/totals/last', daysBack: @state.daysBack, datanames: ['end_of_day_total']})
          ],
          div className: "row", [
            (p className: "section-description",
              "Up and finished counts per day."),
            (Graph {urlbase: '/api/diffs/last', daysBack: @state.daysBack, datanames: ['up_count', 'finished_count']})
          ],
          div className: "row", [
            (p className: "section-description",
              "Heatmap of finished tasks per day."),
            (Heatmap {urlbase: '/api/diffs/last', daysBack: @state.daysBack, datanames: ['finished_count']})
          ],
          div className: "row", [
            (TimeAdjust update: @updateLinechartTime)
          ]
        ]
      ]
      
  $ ->
    React.render (Ui {}), document.body
