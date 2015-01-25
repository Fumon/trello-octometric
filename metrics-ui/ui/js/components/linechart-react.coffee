define ['d3', 'react', 'jquery', 'components/linechart-d3'], (d3, react, $, chart) ->
  react.createFactory react.createClass
    displayName: 'lineplot'
    propTypes:
      data: react.PropTypes.array
      margin: react.PropTypes.object
      domainmargin: react.PropTypes.number
    
    componentDidMount: () ->
      @chart = new chart.linechart
        
      @chart.create @getDOMNode(),
        {
          datanames: @props.datanames
          domainmargin: @props.domainmargin
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

        
