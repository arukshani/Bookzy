package samples.hackathon.ballerinabot;

import ballerina.net.http;
import ballerina.lang.system;
import ballerina.lang.messages;
import ballerina.lang.xmls;
import ballerina.lang.jsons;
import ballerina.lang.strings;
import ballerina.doc;

const string GOODREADS_DEV_KEY = "0EM50z4WoxaQwJgrxwLw";

@http:config { basePath: "/webhook", port: 9096}
@doc:Description{value : "This represents ballerina helper service that talks to goodreads connector and fb messenger bot"}
service<http> Service1 {

    @http:GET {}
    @http:Path { value: "/"}
    @doc:Description{value : "This is required for fb callback url verification"}
    resource Resource1 (message m,
@http:QueryParam { value: "hub.challenge"}
string challenge) {
        message response = {};
        messages:setStringPayload(response,challenge);
        reply response;
    }

    @http:POST {}
    @http:Path { value: "/"}
    @doc:Description{value : "Accept user search value, then find required details and post to bot"}
    resource Resource4 (message m) {
        message response = {};
        
        json messengerPayload = messages:getJsonPayload(m);
        system:println(messengerPayload);
        //NOTE; Only the admin can send and receive mesages at the moment
        string recipientId = jsons:getString(messengerPayload,"$.entry[0]messaging[0].sender.id");
        system:println(recipientId);
        string messageTxt = jsons:getString(messengerPayload,"$.entry[0]messaging[0].message.text");
        system:println(messageTxt);
        
        string[] txtArray = strings:split(messageTxt,"\\s");
        string finder = txtArray[0];
        int messageTxtLength = strings:length(messageTxt);
        string searchValue = strings:subString(messageTxt,2,messageTxtLength);
        system:println("SEARCH VALUE >> " + searchValue);
        system:println("TOKEN FINDER >> " + finder);
        
        json jsonPayload = {"recipient": {"id": recipientId},"message": {"text": "Sorry, I could not find anything!"}};
        
        //If the user-search, starts with * that means an author search
        if (strings:equalsIgnoreCase(finder,"*")) {
            message request = {};
            messages:addHeader(request,"author_name",searchValue);
            message gdResponse = findAuthor(request);
            xml xmlPayload = messages:getXmlPayload(gdResponse);
            xml authorLink = xmls:getXml(xmlPayload,"/GoodreadsResponse/author/link");
            string authorLinkStr = xmls:getTextValue(authorLink);
            xml authorName = xmls:getXml(xmlPayload,"/GoodreadsResponse/author/name");
            string authorNameStr = xmls:getTextValue(authorName);
            jsonPayload = {"recipient": {"id": recipientId},"message": {"attachment": {"type": "template","payload": {"template_type": "generic","elements": [{"title": "Goodreads Official Page","subtitle": "Following link will direct you to author's page!","item_url": "","image_url": "","buttons": [{"type": "web_url","url": authorLinkStr,"title": authorNameStr}]}]}}}};
        
        } else {
            //This part handles all other searches. Good reads will try to find a book by title, author, or ISBN.
            message request = {};
            messages:addHeader(request,"search_value",messageTxt);
            message gdResponse = findBook(request);
            xml xmlPayload = messages:getXmlPayload(gdResponse);
            //Only the first search result is taken into consideration here. Search accuracy is good as goodreads api 
            xml bookDetails = xmls:getXml(xmlPayload,"/GoodreadsResponse/search/results/work[1]");
            system:println(bookDetails);
            jsonPayload = buildJsonPayload(bookDetails,recipientId);
        }
        messages:setJsonPayload(response,jsonPayload);
        string access_token = "EAAEcKYPrS60BALZBtwLPPjNmoctG3wR3KKRZAWME2DriZCuZBX9u5VPKtskMrpTpySeyCNNMWerGkNk0nsKOByU4jv8TavcK6z4riTcude7A0ErYLgd1PX4g3kroNtcAm5SnhDIRldM6MOvnnTeOqTICpg8ztN2HjqLnWYkLuwZDZD";
        FBMessengerBot fbBot = create FBMessengerBot(access_token);
        message botResponse = FBMessengerBot.sendMessage(fbBot, response);
        reply botResponse;
    }

    @http:GET {}
    @http:Path { value: "/author/{author_name}"}
    @doc:Description{value : "This is not used by bot. Other apps can use this to find author details by name"}
    resource Resource2 (message m,
@http:PathParam { value: "author_name"}
string author_name) {
        message response = {};
        message request = {};
        messages:addHeader(request,"author_name",author_name);
        message gdResponse = findAuthor(request);
        xml xmlPayload = messages:getXmlPayload(gdResponse);
        system:println(xmlPayload);
        
        xml linkval = xmls:getXml(xmlPayload,"/GoodreadsResponse/author/link");
        string valstr = xmls:getTextValue(linkval);
        system:println(valstr);
        messages:setStringPayload(response,valstr);
        reply response;
    }

    @http:GET {}
    @http:Path { value: "/search"}
    @doc:Description{value : "This is not used by bot. Other apps can use this to find book details by title, author, or ISBN."}
    resource Resource3 (message m,
@http:QueryParam { value: "q"}
string q) {
        message response = {};
        message request = {};
        messages:addHeader(request,"search_value",q);
        message gdResponse = findBook(request);
        xml xmlPayload = messages:getXmlPayload(gdResponse);
        
        xml bookDetails = xmls:getXml(xmlPayload,"/GoodreadsResponse/search/results/work[1]");
        system:println(bookDetails);
        messages:setXmlPayload(response,bookDetails);
        reply response;
    }
}

@doc:Description{value : "Find author from good reads connector"}
function findAuthor (message request) (message) {
    GoodReads gdConnector = create GoodReads(GOODREADS_DEV_KEY);
    message gdResponse = GoodReads.findAuthor(gdConnector, request);
    return gdResponse;
}

@doc:Description{value : "Find books details from good reads connector"}
function findBook (message request) (message) {
    //Find books by title, author, or ISBN.
    GoodReads gdConnector = create GoodReads(GOODREADS_DEV_KEY);
    message gdResponse = GoodReads.findBook(gdConnector, request);
    return gdResponse;
}

@doc:Description{value : "build json payload required by messnger bot for book details"}
function buildJsonPayload (xml bookDetails, string recipientId) (json) {
    
    xml avgRating = xmls:getXml(bookDetails,"/work/average_rating");
    string avgRatingStr = xmls:getTextValue(avgRating);
    avgRatingStr = "Avg Rating: " + avgRatingStr;
    
    xml ratingCount = xmls:getXml(bookDetails,"/work/ratings_count");
    string ratingCountStr = xmls:getTextValue(ratingCount);
    ratingCountStr = ratingCountStr + " Ratings";
    
    xml reviewCount = xmls:getXml(bookDetails,"/work/text_reviews_count");
    string reviewCountStr = xmls:getTextValue(reviewCount);
    reviewCountStr = reviewCountStr + " Reviews";
    
    xml publishYear = xmls:getXml(bookDetails,"/work/original_publication_year");
    string publishYearStr = xmls:getTextValue(publishYear);
    publishYearStr = "Published in: " + publishYearStr;
    
    xml title = xmls:getXml(bookDetails,"/work/best_book/title");
    string titleStr = xmls:getTextValue(title);
    
    xml author = xmls:getXml(bookDetails,"/work/best_book/author/name");
    string authorStr = xmls:getTextValue(author);
    authorStr = authorStr + " : " + ratingCountStr + " ~GoodReads~";
    
    xml bookImg = xmls:getXml(bookDetails,"/work/best_book/image_url");
    string bookImgStr = xmls:getTextValue(bookImg);
    
    json jsonPayload = {"recipient": {"id": recipientId},"message": {"attachment": {"type": "template","payload": {"template_type": "generic","elements": [{"title": titleStr,"subtitle": authorStr,"item_url": "","image_url": "","buttons": [{"type": "web_url","url": bookImgStr,"title": avgRatingStr},{"type": "web_url","url": bookImgStr,"title": reviewCountStr},{"type": "web_url","url": bookImgStr,"title": publishYearStr}]}]}}}};
    return jsonPayload;
}
