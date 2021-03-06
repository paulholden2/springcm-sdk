require "uuid"
require_relative "fake_service"

# Mock SpringCM Object API service.
class FakeSpringcm < FakeService
  @@ratelimit = true
  @@auth_expired = true
  @@access_token = nil
  @@deleted_documents = Set.new

  def initialize
    @root_uid = UUID.generate
    @ratelimit = true
    super
  end

  get "/v201411/ratelimit" do
    if @@ratelimit
      @@ratelimit = false
      json_response 429, {
        "Error" => {
          "HttpStatusCode" => 429,
          "UserMessage" => "Rate limit exceeded.",
          "DeveloperMessage" => "Rate limit exceeded.",
          "ErrorCode" => 103,
          "ReferenceId" => UUID.generate
        }
      }.to_json
    else
      json_response 200, {}.to_json
    end
  end

  get "/v201411/authexpire" do
    access_token = request.env['HTTP_AUTHORIZATION'].match(/bearer (.*)/)[1]
    if @@auth_expired
      @@auth_expired = false
      @@access_token = access_token
      json_response 401, {
        "Error" => {
          "HttpStatusCode" => 401,
          "UserMessage" => "Access Denied",
          "DeveloperMessage" => "Access Denied",
          "ErrorCode" => 103,
          "ReferenceId" => UUID.generate
        }
      }.to_json
    else
      raise "client did not retry with new access token" if access_token == @@access_token
      json_response 200, {}.to_json
    end
  end

  get "/v201411/accounts/current" do
    builder = AccountBuilder.new(client)
    json_response 200, builder.data.to_json
  end

  get "/v201411/accounts/current/attributegroups" do
    account = AccountBuilder.new(client)
    builder = PageBuilder.new("#{account.build.href}/attributegroups", Springcm::AttributeGroup, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      attribute_group = AttributeGroupBuilder.new(client)
      builder.add(attribute_group)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/groups" do
    account = AccountBuilder.new(client)
    builder = PageBuilder.new(account.build.href, Springcm::Group, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      group = GroupBuilder.new(client).uid(UUID.generate)
      builder.add(group)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/groups/:group_uid" do
    group = GroupBuilder.new(client).uid(params["group_uid"])
    json_response 200, group.data.to_json
  end

  get "/v201411/groups/:group_uid/groupmembers" do
    group = GroupBuilder.new(client).uid(params["group_uid"])
    builder = PageBuilder.new(group.build.href, Springcm::User, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      user = UserBuilder.new(client).uid(UUID.generate)
      builder.add(user)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/users" do
    account = AccountBuilder.new(client)
    builder = PageBuilder.new(account.build.href, Springcm::User, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      user = UserBuilder.new(client).uid(UUID.generate)
      builder.add(user)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/users/:user_uid" do
    user = UserBuilder.new(client).uid(params["user_uid"])
    json_response 200, user.data.to_json
  end

  get "/v201411/users/:user_uid/groups" do
    user = UserBuilder.new(client).uid(params["user_uid"])
    builder = PageBuilder.new(user.build.href, Springcm::Group, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      group = GroupBuilder.new(client).uid(UUID.generate)
      builder.add(group)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/attributegroups/:attributegroup_uid" do
    builder = AttributeGroupBuilder.new(client).uid(params["attributegroup_uid"])
    json_response 200, builder.data.to_json
  end

  get "/v201411/folders" do
    if params["systemfolder"] == "root" || params["path"] == "/"
      builder = FolderBuilder.new(client).uid(@root_uid)
      json_response 200, builder.data.to_json
    elsif !params["path"].nil?
      builder = FolderBuilder.new(client).uid(UUID.generate)
      builder.name(params["path"].split("/").last)
      json_response 200, builder.data.to_json
    else
      # Stub the validation errors
      json_response 422, {
        "Error" => {},
        "ValidationErrors" => []
      }
    end
  end

  post "/v201411/folders" do
    builder = FolderBuilder.new(client)
    parent_builder = FolderBuilder.new(client)
    body = JSON.parse(request.body.read)
    builder.parent(Springcm::Folder.new(body["ParentFolder"], client))
    builder.uid(UUID.generate)
    builder.name(body["Name"])
    json_response 201, builder.data.to_json
  end

  get "/v201411/folders/:folder_uid" do
    builder = FolderBuilder.new(client).uid(params[:folder_uid])
    json_response 200, builder.data.to_json
  end

  patch "/v201411/folders/:folder_uid" do
    builder = FolderBuilder.new(client).uid(params[:folder_uid])
    json_response 200, builder.data.to_json
  end

  delete "/v201411/folders/:folder_uid" do
    builder = FolderBuilder.new(client).uid(params[:folder_uid])
    json_response 200, builder.data.to_json
  end

  get "/v201411/folders/:folder_uid/folders" do
    parent_folder = FolderBuilder.new(client).uid(params["folder_uid"]).build
    builder = PageBuilder.new(parent_folder.href, Springcm::Folder, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    parent = FolderBuilder.new(client).build
    50.times do
      folder = FolderBuilder.new(client).uid(UUID.generate).parent(parent)
      builder.add(folder)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/folders/:folder_uid/documents" do
    parent_folder = FolderBuilder.new(client).uid(params["folder_uid"]).build
    builder = PageBuilder.new(parent_folder.href, Springcm::Document, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    folder = FolderBuilder.new(client).build
    5.times do
      document = DocumentBuilder.new(client).uid(UUID.generate).parent(folder)
      builder.add(document)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/documents" do
    if !params["path"].nil?
      builder = DocumentBuilder.new(client).name(File.basename(params["path"]))
      json_response 200, builder.data.to_json
    else
      # SpringCM returns 404 instead of a validation error. Weird.
      json_response 404, {
        "Message" => "No HTTP resource was found that matches the request URI '#{request.url}'"
      }
    end
  end

  get "/v201411/documents/:document_uid" do
    builder = DocumentBuilder.new(client).uid(params[:document_uid])
    if @@deleted_documents.include?(params[:document_uid])
      builder.delete!
    end
    json_response 200, builder.data.to_json
  end

  get "/v201411/documents/:document_uid/historyitems" do
    document = DocumentBuilder.new(client).uid(params["document_uid"]).build
    builder = PageBuilder.new(document.href, Springcm::HistoryItem, client).offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.times do
      history_item = HistoryItemBuilder.new(client)
      builder.add(history_item)
    end
    json_response 200, builder.build.to_json
  end

  get "/v201411/documents/:document_uid/versions" do
    document = DocumentBuilder.new(client).uid(params["document_uid"]).build
    builder = PageBuilder.new(document.href, Springcm::Document, client, resource_override: "versions").offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 20).to_i)
    50.downto(1) do |ver|
      document = DocumentBuilder.new(client).uid(UUID.generate).version(ver)
      builder.add(document)
    end
    json_response 200, builder.build.to_json
  end

  patch "/v201411/documents/:document_uid" do
    builder = DocumentBuilder.new(client).uid(params[:document_uid])
    json_response 200, builder.data.to_json
  end

  delete "/v201411/documents/:document_uid" do
    builder = DocumentBuilder.new(client).uid(params[:document_uid])
    @@deleted_documents << params[:document_uid]
    json_response 200, builder.data.to_json
  end

  get "/v201411/changesecuritytasks/:task_uid" do
    folder = FolderBuilder.new(client).uid(UUID.generate).build
    group = GroupBuilder.new(client).uid(UUID.generate).build
    builder = ChangeSecurityTaskBuilder.new(client).uid(params["task_uid"]).folder(folder).group(group).status("Waiting")
    json_response 200, builder.data.to_json
  end

  post "/v201411/changesecuritytasks" do
    folder = FolderBuilder.new(client).uid(UUID.generate).build
    group = GroupBuilder.new(client).uid(UUID.generate).build
    builder = ChangeSecurityTaskBuilder.new(client).folder(folder).group(group).status("Waiting")
    json_response 200, builder.data.to_json
  end

  private

  def client
    Springcm::Client.new("uatna11", "client_id", "client_secret")
  end
end
