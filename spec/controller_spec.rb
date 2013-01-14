require 'spec_helper'

describe 'App' do

  def app
    Sinatra::Application
  end

  context "/" do
    
    context "GET" do
    
      it "renders 200" do
        get '/', {}, MockSessionHash
        last_response.should be_ok
      end
    
    end
    
    context "POST" do
      
      context "Unknown payload" do
        let(:payload){{"invalid" => "stuff"}}
        it "raises and aborts" do
          -> {  
            post '/', {"payload" => payload.to_json}
          }.should raise_error(SystemExit)
        end
      end
      
      context "GitHub Payload" do
        context "Invalid" do
          context "with missing name" do 
            let(:payload){
              {
                "repository" => {
                  "name" => nil, 
                  "url" => "https:\/\/github.com\/ruhoh\/ruhoh.com",
                }
              }
            }
            it "raises and aborts" do
              -> {  
                post '/', {"payload" => payload.to_json}
              }.should raise_error(SystemExit)
            end
          end
        end
        context "Valid" do
          let(:payload){
            {
              "repository" => {
                "name" => "ruhoh.com", 
                "owner" => {
                  "name" => "ruhoh"
                },
                "url" => "https:\/\/github.com\/ruhoh\/ruhoh.com",
              }
            }
          }
          it "return 204 success code" do
            post '/', {"payload" => payload.to_json}
            last_response.status.should == 204
          end
        end
      end
    end
  end

  context "POST /repos/:name" do
    
    context "Domain exists" do
      let(:record){Parse::Object.new("Repo")}

      context "and owned by another user" do
        let(:domain_check_record){
          r = Parse::Object.new("Repo")
          r["domain"] = "cooldomain.com"
          r
        }
        it "should not save, set flash error and redirect" do 
          Repo.stub(:all).and_return([domain_check_record])
          Repo.stub(:find_or_build).and_return(record)

          payload = {"domain" => "cooldomain.com"}
          post "/repos/ruhoh.com", payload, MockSessionHash

          record.should_not_receive(:save)
          flash = last_request.env["rack.session"]["__FLASH__"] rescue {}
          flash.should have_key(:error)
          last_response.should be_redirect
        end
      end
      
      context "and owned by same user" do
        let(:domain_check_record){
          r = Parse::Object.new("Repo")
          r["user"] = "plusjade"
          r["domain"] = "cooldomain.com"
          r
        }
        it "should not save, set flash error and redirect" do 
          Repo.stub(:all).and_return([domain_check_record])
          Repo.stub(:find_or_build).and_return(record)

          payload = {"domain" => "cooldomain.com"}
          post "/repos/ruhoh.com", payload, MockSessionHash

          record.should_not_receive(:save)
          flash = last_request.env["rack.session"]["__FLASH__"] rescue {}
          flash.should have_key(:error)
          record.should_not_receive(:save)
        end
      end
      
      context "and owned by same user and is same repo" do
        let(:domain_check_record){
          r = Parse::Object.new("Repo")
          r["user"] = "plusjade"
          r["name"] = "ruhoh.com"
          r["domain"] = "cooldomain.com"
          r
        }
        it "should not save, set flash notice and redirect" do 
          Repo.stub(:all).and_return([domain_check_record])
          Repo.stub(:find_or_build).and_return(record)

          payload = {"domain" => "cooldomain.com"}
          post "/repos/ruhoh.com", payload, MockSessionHash

          record.should_not_receive(:save)
          flash = last_request.env["rack.session"]["__FLASH__"] rescue {}
          flash.should have_key(:notice)
          record.should_not_receive(:save)
        end
      end
    end
      
    context "Domain does not exist" do
      
    end
    
  end
  
end