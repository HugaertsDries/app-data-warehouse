defmodule Dispatcher do
  use Matcher

  define_accept_types [
    html: [ "text/html", "application/xhtml+html" ],
    json: [ "application/json", "application/vnd.api+json" ],
    sparql: [ "application/sparql-results+json" ]
  ]

  @any %{}
  @json %{ accept: %{ json: true } }
  @html %{ accept: %{ html: true } }
  @sparql %{ accept: %{ sparql: true } }

  match "/sparql", @html do
    forward conn, [], "http://yasgui:80"
  end

  match "/sparql", @sparql do
    forward conn, [], "http://database:8890/sparql"
  end

  # Temporary Redirect to "/sparql" endpoint
  match "/*_", @html do
    send_resp( conn, 307, "<!DOCTYPE html><html><head><meta http-equiv=\"refresh\" content=\"0; url='/sparql'\" /></head><body><p>Please follow <a href=\"/sparql\">this link</a>.</p></body></html>" )
  end

  match "/*_", %{ last_call: true } do
    send_resp( conn, 404, "Route not found.  See config/dispatcher.ex" )
  end

end
