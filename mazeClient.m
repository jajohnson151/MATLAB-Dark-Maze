function mazeClient(serverIpAddr,port)

arguments
    serverIpAddr(1,:) char = "localhost"
    port(1,1) double = 15151
end % arguments

global G_ClientSockId %#ok<*GVMIS> 
global G_lastServerIpAddr

if serverIpAddr == "close"
    if ~isempty(G_ClientSockId) && G_ClientSockId ~= -1
        sclose(G_ClientSockId);
        G_ClientSockId = [];
    end
    return
end

myMaze = mazeClass;

% Close the old socket if the server address has changed
if ~isempty(G_lastServerIpAddr) && ~strcmp(arguments,G_lastServerIpAddr) && ~isempty(G_ClientSockId) && G_ClientSockId ~= -1
    sclose(G_ClientSockId);
    G_ClientSockId = [];
end

% Establish connection to server
if isempty(G_ClientSockId) || G_ClientSockId == -1
    G_ClientSockId = connectToServer(serverIpAddr,port);
    if G_ClientSockId == -1
        error('Unable to connect to server at "%s"', serverIpAddr)
    end
end

header_attr = cstruct(HEADER_TYPE);

STATE_WAITING_FOR_DESIGN = 1;
STATE_EXPLORING = 2;
% Now that we are connected to the client, we can start waiting for server
% messages, or user interactions
state = STATE_WAITING_FOR_DESIGN;
while 1
    [n,sockIdList] = swait(G_ClientSockId,0.01);
    % TODO: How do we want for user interaction?
    if n < 0
        fprintf('Server disconnected. Ending.')
        break
    end
    if n == 0
        continue
    end
    byteCount = speek(G_ClientSockId);
    if byteCount < 0
        fprintf('Server disconnected. Ending.')
        break
    end
    if byteCount >= header_attr.size
        % Never sread without speek making sure there's enough data.
        header = sread(G_ClientSockId,HEADER_TYPE);
        dataBytes = sread(G_ClientSockId,double(header.byteCount));
        switch header.messageType
            case MESSAGE_ENUM_TYPE.MT_MAZEDESIGN
                txt = char(dataBytes);
                data = jsondecode(txt);
                myMaze.setDesign(data);
                fprintf('Maze design received from server.\n')
        end
    end % if byteCount >= header_attr.size
end % while 1

end % function mazeClient

%---------------------------------------------------------------
% connectToServer
function clientSockID = connectToServer(serverIpAddr,port)
arguments
    serverIpAddr(1,:) char
    port(1,1) double = 15151
end % arguments

retryCount = 0;
while true
    clientSockID = sopen(serverIpAddr,'ws',port);
    if clientSockID == -1
        retryCount = retryCount + 1;
        if retryCount == 1
            fprintf('Unable to connect to "%s" port %d; retrying ...\n', serverIpAddr, port);
        end
        pause(0.5);
    else
        break
    end
end % while true

end % function connectToServer

