requirejs.config
  paths:
    jquery: 'https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min'
    react: 'https://fb.me/react-0.12.2'
    d3: 'https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3'

require ['jquery', 'd3', 'react'], ($, d3, React) ->
  {div, h4, p} = React.DOM

  Graph = React.createFactory React.createClass
    getInitialState: ->
      todoTotals: {}
    componentDidMount: ->
      $.get '/api/totals/last/5', (result) ->
        data = result[0]
        this.setState {data: data}
    render: ->
      div id: 'chart'

  Ui = React.createFactory React.createClass
    render: ->
      div className: "section", [
        div className: "container", [
          div className: "row", [
            (h4 className: "section-heading", "Basic Daily Report"),
            (p className: "section-description",
              "This graph shows the total number of tasks on the todo board over time."),
            (Graph)
          ]
        ]
      ]
      
  $ ->
    React.render (Ui {}), document.body
