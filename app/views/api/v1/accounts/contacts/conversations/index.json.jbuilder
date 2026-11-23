json.payload do
  json.array! @conversations do |conversation|
    json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: conversation
  end
end
json.meta do
  json.current_page @current_page
  json.has_more @has_more
end
