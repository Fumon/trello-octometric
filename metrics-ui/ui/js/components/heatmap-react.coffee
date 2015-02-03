define ['d3', 'react', 'calheatmap'], (d3, react, calheatmap) ->
  react.createFactory react.createClass
    displayName: 'heatmapChart'
    propTypes:
      data: react.PropTypes.array
    componentDidMount: () ->
      # Reformat data
      @cal = new calheatmap()
      @cal.init
        itemSelector: @getDOMNode()
        domain: 'month'
    doChartUpdate: () ->
      firstdate = d3.min(@props.data, (d) -> d.day)
      ndata = {}
      for d in @props.data
        ndata["#{d.day}"] = d.finished_count
      setTimeout((() => @cal.update ndata), 1200)
      @cal.jumpTo new Date(firstdate * 1000)

    componentDidUpdate: () ->
      @doChartUpdate()
    
    render: () ->
      react.DOM.div className: 'cal-heatmap'
