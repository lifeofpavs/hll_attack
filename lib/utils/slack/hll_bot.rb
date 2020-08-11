module Utils
  module Slack
    class HllBot
      def self.send_message(message, channel)
      
        begin 
           HTTParty.post("https://slack.com/api/chat.postMessage", 
                          :body => {
                                "channel": channel,
                                "attachments": get_attachment(message)
                                  }.to_json ,
                          :headers=> {
                                    "Authorization": "Bearer #{ENV["SLACK_TOKEN"]}",
                                    "Content-type": "application/json"
                                     }
                          )
  
        rescue => e #Error sending to slack Normaly is a error with the channel name
          puts e.message
          return false
        end
      end
  
      def self.get_attachment(message)
        attachments = [{
          color: "#95BF46",
          text: message,
          title: "Simulation",
          footer: "HLL Bot"
        }]
      end
  
  
    end
  end
end
