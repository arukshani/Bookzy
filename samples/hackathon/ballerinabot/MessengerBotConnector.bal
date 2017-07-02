package samples.hackathon.ballerinabot;

import ballerina.net.http;
import ballerina.doc;

@doc:Description{value : "Custom connector to post to FB messenger bot"}
connector FBMessengerBot (string access_token) {
    
    http:ClientConnector botEP = create http:ClientConnector ("https://graph.facebook.com");

    action sendMessage (FBMessengerBot bot , message inboundMsg) (message) {
        
        message outboundMsg = http:ClientConnector.post(botEP,"/v2.6/me/messages?access_token=" + access_token ,inboundMsg);
        return outboundMsg;
    }
}
