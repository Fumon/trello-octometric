define ['d3', 'react', 'jquery', 'components/histogram-d3'], (d3, react, $, chart) ->
  react.createFactory react.createClass
    displayName: 'histoplot'
    propTypes:
      data: react.PropTypes.array
      margin: react.PropTypes.object
      bins: react.PropTypes.number
    
    componentDidMount: () ->
      @chart = new chart.histogram
        
      @chart.create @getDOMNode(),
        {
          datanames: @props.datanames
          bins: @props.bins
          margin: @props.margin
          width: @props.width
          height: @props.height
        },
        data: @props.data

        # Create resize bind
        $(window).resize @doChartUpdate
    doChartUpdate: () ->
      @chart.update @getDOMNode(),
        data: @props.data

    componentDidUpdate: () ->
      @doChartUpdate()
    
    render: () ->
      react.DOM.div className: 'linechart'

        
