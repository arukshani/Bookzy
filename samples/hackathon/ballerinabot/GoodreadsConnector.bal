package samples.hackathon.ballerinabot;

import ballerina.net.http;
import ballerina.lang.system;
import ballerina.lang.messages;
import ballerina.doc;

@doc:Description{value : "Custom connector that uses GoodReads API. Only two methods are implemented here. Full set of methods can be found here > www.goodreads.com/api"}
connector GoodReads (string key) {
    
    http:ClientConnector goodReadsEP = create http:ClientConnector ("https://www.goodreads.com");

    action findAuthor (GoodReads gd , message inboundMsg) (message) {
        // Find an author by name.
        string author_name = messages:getHeader(inboundMsg,"author_name");
        string getAuthorPath = "/api/author_url/" + author_name +"?key="+key;
        system:println(getAuthorPath);
        message response = http:ClientConnector.get(goodReadsEP, getAuthorPath, inboundMsg);
        return response;
    }
    
    
    action findBook (GoodReads gd , message inboundMsg) (message){
        //Find books by title, author, or ISBN.
        string search_value = messages:getHeader(inboundMsg,"search_value");
        string searchBookPath = "/search/index.xml?key=" + key + "&q=" + search_value;
        system:println(searchBookPath);
        message response = http:ClientConnector.get(goodReadsEP, searchBookPath, inboundMsg);
        return response;
    }
}
