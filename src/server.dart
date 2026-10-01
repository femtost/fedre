// Libs
import 'dart:io';
import "dart:convert";
import "dart:async";
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

// Globals
const ROOT_SERVER = "s1.femtost.com";
var currentServerIp;
var rootServerIp;
var isOnRootServer;
var thisServerAddr;

// Client uses session id to query root server
// Only root server
var user2sid = {}; // username+number -> session id

// Client uses socket to query to member server
// Any server
var user2loc = {}; // username+number -> serverAddress
var sockets = {}; // username+number -> socketVar

// Get ip
Future<String> machineIp() async{
    final ip = (await http.get(Uri.parse('https://api.ipify.org'))).body;
    return ip;
}

// Get root server ip
Future<String> rootMachineIp() async{
    final ip = (await InternetAddress.lookup(ROOT_SERVER)).first.address;
    return ip;
}

// Asynchronous write function
Future<void> writeFile(String path, String data) async {
    final file = File(path);
    await file.writeAsString(data);
}

// Asynchronous read function
Future<String> readFile(String path) async {
    final file = File(path);

    if (await file.exists()) {
        return await file.readAsString();
    } else {
        throw Exception('File not found at $path');
    }
}

// Check dir
bool dirExists(String dirPath) {  
    // Check if a Directory exists synchronously
    bool exists = Directory(dirPath).existsSync();
    return exists;
}

// Check file
bool fileExists(String filePath) {
    // Check if a File exists synchronously
    bool exists = File(filePath).existsSync();
    return exists;
}

// To json
String toJson(obj){
    return jsonEncode(obj);
}

// From json
dynamic fromJson(str){
    try { return jsonDecode(str); }
    catch(_){ return null; }
}

// Make sha1 of string
String makeSha1(str){
    final hash = sha1.convert(utf8.encode(str)).toString();
    return hash;
}

// Random
double Math_random(){
    final n = Random().nextDouble();
    return n;
}

// Rand str
String randString(){
    var t = Math_random().toString().replaceAll(".","");
    return t;
}

// Http get
Future<String> httpxGet(url) async{
    final response = await http.get( Uri.parse(url) );
    return response.body;
}

// Reg
Future<dynamic> regOnRootServer(username,number,salt,pwHash) async{
    var fileName = "$username+$number.json";
    var path = "/var/lib/fedre/users/$fileName";    

    if (fileExists(path))
        return {"error":"user-exists"};

    var json = toJson({
        "username":username, "number":number, "salt":salt, "pwHash":pwHash
    });
    await writeFile(path,json);
    var check = await readFile(path);
    print("New user: $check");
    return {"msg":"ok"};
}

// Reg
Future<dynamic> callRootServerToReg(username,number,salt,pwHash) async{
    return {"error":"not-implemented"};
}

// Register
Future<dynamic> register(request) async{
    final bodyStr = await utf8.decoder.bind(request).join();
    var body = fromJson(bodyStr);
    var username = body["username"];
    var number = body["number"];
    var pw = body["password"];

    if (username==null || number==null || pw==null
            || username.trim().length==0 || number.trim().length==0 || pw.trim().length==0)
        return {"error":"bad-params"};

    // Check existence
    username = username.toLowerCase();
    number = number.toLowerCase();

    if (!RegExp(r"^[0-9a-z]+$").hasMatch(username))
        return {"error":"bad-characters-in-username"};     
        
    if (!RegExp(r"^[0-9]+$").hasMatch(number))    
        return {"error":"bad-chars-in-number"};

    if (pw.indexOf("\x20") >= 0)
        return {"error":"password-cant-contain-spaces"};    
    
    var salt = Math_random().toString();
    var pwHash = makeSha1(pw+salt);    

    // Create
    if (currentServerIp==rootServerIp)
        return await regOnRootServer(username,number,salt,pwHash);
    else 
        return await callRootServerToReg(username,number,salt,pwHash);    
}

// Mark user being on a server
Future<dynamic> saveUserLocation(request) async{
    var params = request.uri.queryParameters;
    var username = params["u"];
    var number = params["n"];
    var pw = params["p"];
    var server = params["s"];

    if (username==null || number==null || pw==null || server==null 
            || username.trim().length==0 || number.trim().length==0 || pw.trim().length==0
            || server.trim().length==0)
        return {"error":"bad-params"};

    // Check existence
    username = username.toLowerCase();
    number = number.toLowerCase();

    if (!RegExp(r"^[0-9a-z]+$").hasMatch(username))
        return {"error":"bad-characters-in-username"};     
        
    if (!RegExp(r"^[0-9]+$").hasMatch(number))    
        return {"error":"bad-chars-in-number"};

    if (pw.indexOf("\x20") >= 0)
        return {"error":"password-cant-contain-spaces"};    
    
    var fileName = "$username+$number.json";
    var path = "/var/lib/fedre/users/$fileName";    

    if (!fileExists(path))
        return {"error":"no-such-user"};

    // Check pw
    var json = await readFile(path);
    var info = fromJson(json);
    var salt = info["salt"];
    var pwHashInput = makeSha1(pw+salt);

    if (pwHashInput != info["pwHash"])
        return {"error":"bad-password"};

    // All ok, mark user location as being on server at params['s']
    user2loc["$username+$number"] = server;
    print("$username+$number is now on $server");
    var sid1 = randString();
    var sid2 = randString();
    var sid3 = randString();
    var sid = "$sid1-$sid2-$sid3";
    user2sid["$username+$number"] = sid;
    return {"msg":"ok", "sessionId":sid};
}

// Locate user
Future<dynamic> locateUser(request) async{
    final bodyStr = await utf8.decoder.bind(request).join();
    var body = fromJson(bodyStr);
    var username = body["myUsername"];
    var number = body["myNumber"];
    var sid = body["sessionId"];
    var findUsername = body["findUsername"];
    var findNumber = body["findNumber"];

    if (username==null || number==null || sid==null
            || username.trim().length==0 || number.trim().length==0 || sid.trim().length==0)
        return {"error":"bad-params"};

    // Check sid
    if (user2sid["$username+$number"]!=sid)
        return {"error":"bad-session"};

    // Get loc
    if (user2loc["$findUsername+$findNumber"]==null)
        return {"info":"no-user-or-not-online"};

    return {"targetServer":user2loc["$findUsername+$findNumber"]};
}

// Send msg to user
Future<dynamic> sendMessage(request) async{
    final bodyStr = await utf8.decoder.bind(request).join();
    var body = fromJson(bodyStr);
    var from = body["from"];
    var username = body["targetUsername"];
    var number = body["targetNumber"];
    var msg = body["message"];

    if (username==null || number==null || msg==null
            || username.trim().length==0 || number.trim().length==0 || msg.trim().length==0)
        return {"error":"bad-params"};

    // Check socket
    var sock = sockets["$username+$number"];
    if (sock==null)
        return {"error":"no-such-user-here"};

    // Send
    sock.add(toJson({
        "dataType":"incoming-msg", "from":from, "message":msg 
    }));
    return {"msg":"sent"};
}

// Accept ws
Future<void> receiveWebSocket(request,response,socket) async{
    var params = request.uri.queryParameters;
    var user = params["u"];
    var num = params["n"];
    var pw = params["p"];

    if (user==null || num==null || pw==null || user.trim().length==0 ||
            num.trim().length==0 || pw.trim().length==0){
        socket.add(toJson({"error":"bad-ws-url"}));
        await socket.close();
        return;
    }

    // Check auth
    if (!isOnRootServer){
        // Use httpxGet to check auth on root server
        // todo
        socket.add(toJson({"error":"non-root-server-not-implemented"}));
        await socket.close();
        return;
    }
    var fileName = "$user+$num.json";
    var path = "/var/lib/fedre/users/$fileName";   
    print(path); 

    if (!fileExists(path)){
        print("Bad user: $fileName");
        socket.add(toJson({"error":"no-such-user"}));
        await socket.close();
        return;
    }
    var json = await readFile(path);
    var info = fromJson(json);
    var salt = info["salt"];
    var pwHashInput = makeSha1(pw+salt);
    var pwHash = info["pwHash"];

    if (pwHashInput != pwHash){
        socket.add(toJson({"error":"bad-password"}));
        await socket.close();
        return;
    }

    // Ok socket
    socket.listen(
        (message) {
            print('Received: $message');
            socket.add('Echo: $message');
        },
        onDone: () {
            print('WebSocket disconnected');
        },
        onError: (error) {
            print('WebSocket error: $error');
        },
    );
    sockets["$user+$num"] = socket;

    // Tell root server that socket of user is here
    var notifUrl = "https://$ROOT_SERVER/api/user-loc?";
    notifUrl += "u="+Uri.encodeComponent(user);
    notifUrl += "&n="+Uri.encodeComponent(num);
    notifUrl += "&p="+Uri.encodeComponent(pw);
    notifUrl += "&s="+Uri.encodeComponent(thisServerAddr);
    var resultStr = await httpxGet(notifUrl);
    print("User loc result: $resultStr");

    var result = fromJson(resultStr);
    socket.add(toJson({
        "dataType": "session-info",
        "sessionId": result["sessionId"] 
    }));
}

// Main
void main() async {
    if (!dirExists("/var/lib/fedre/users")){
        print("Please create dir path (777): /var/lib/fedre/users");
        return;
    }
    var ip = await machineIp();
    print("IP: $ip");
    var rootIp = await rootMachineIp();
    print("Root IP: $rootIp");
    currentServerIp = ip;
    rootServerIp = rootIp;
    isOnRootServer = currentServerIp==rootServerIp;

    // stdout.write("Enter this server's domain: ");
    // Read a line of text from standard input
    thisServerAddr = "s1.femtost.com"; // stdin.readLineSync(); 
    print("This server is: $thisServerAddr");

    runZonedGuarded(()async{
        // Port 4000: 'A'll in a circle (3 circles in ubuntu logo)
        final server = await HttpServer.bind('0.0.0.0', 4000);
        print('Listening on http://0.0.0.0:4000');

        await for (final request in server) {
            final response = request.response;
            print(request.method);
    
            // WebSocket
            if (request.uri.path == '/connect') {
                final socket = await WebSocketTransformer.upgrade(request);
                print('WebSocket connected');
                receiveWebSocket(request,response,socket);

            // HTTPS    
            } else{
                if (request.uri.path == '/') {
                    response.write('Home');
            
                } else if (request.uri.path == '/api/hello') {
                    response.headers.contentType = ContentType.json;
                    response.write('{"message":"hello"}');
            
                } else if (request.uri.path=="/api/register" && request.method=="POST"){
                    var result = await register(request);
                    response.write(toJson(result));
            
                } else if (request.uri.path=="/api/user-loc" && request.method=="GET"){
                    var result = await saveUserLocation(request);
                    response.write(toJson(result));
            
                } else if (request.uri.path=="/api/locate-user" && request.method=="POST"){
                    var result = await locateUser(request);
                    response.write(toJson(result));
            
                } else if (request.uri.path=="/api/send-msg" && request.method=="POST"){
                    var result = await sendMessage(request);
                    response.write(toJson(result));
            
                } else{
                    response.statusCode = HttpStatus.notFound;
                    response.write('Not found');
                }
                await response.close();
            }
        }
    },(err,stack){
        print("Uncaught Error: $err");
        print("Stack: $stack");
    });
}