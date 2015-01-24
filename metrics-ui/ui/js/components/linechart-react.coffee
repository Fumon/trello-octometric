define ['d3', 'react', 'components/linechart-d3'], (d3, react, chart) ->
  react.createFactory react.createClass
    displayName: 'lineplot'
    propTypes:
      data: react.PropTypes.array
      margin: react.PropTypes.object
    getChartProps: () ->
      margin: @props.margin
      width: @props.width
      height: @props.height
    
    componentDidMount: () ->
      chart.create @getDOMNode(),
        @getChartProps(),
        data: @props.data
    componentDidUpdate: () ->
      chart.update @getDOMNode(),
        data: @props.data
    
    render: () ->
      react.DOM.div className: 'linechart'

        
