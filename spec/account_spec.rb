RSpec.describe Springcm::Account do
  let(:client) { Springcm::Client.new(data_center, client_id, client_secret) }
  let(:account) { client.account }

  before(:each) do
    client.connect!
  end

  it "loads account info" do
    expect(client.account.id).to be_a(String)
  end

  it "loads attribute groups" do
    expect(client.account.attribute_groups.items).to all(be_a(Springcm::AttributeGroup))
  end
end
