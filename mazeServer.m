function mazeServer

global G_ServerSock
global G_ClientSockList
siz = [5 7 1];
myMaze = mazeClass(siz);
myDesign = myMaze.getDesign('format','json');
%myMaze.setDesign(myDesign);

% establish server socket
if isempty(G_ServerSock)
    G_ServerSock = sopen('','rs',15151);
end

header_attr = cstruct(HEADER_TYPE);

% MAIN LOOP - Wait for a client or a message
while true
    socksToWaitFor = [G_ServerSock,G_ClientSockList];
    [n,socksSelected] = swait(socksToWaitFor,1);
    for ii = 1:n
        sockId = socksSelected(ii);
        if sockId == G_ServerSock
            % A new client wants to connect
            s = saccept(G_ServerSock);
            G_ClientSockList(end+1) = s;
            % Send the maze design over
            [~,dataBytes] = cstruct(myDesign);
            header = HEADER_TYPE(MESSAGE_ENUM_TYPE.MT_MAZEDESIGN,length(dataBytes));
            rc = swrite(s,header)
            rc = swrite(s,dataBytes)
        else
            % There is data from a client socket
            bytesAvail = speek(sockId);
            fprintf('%d bytes avialble on socket %d\n', bytesAvail, sockId);
            if bytesAvail >= header_attr.size
                bytes = sread(sockId,header_attr.size);
                header = cstruct(HEADER_TYPE,bytes)
            end

        end
    end
    fprintf('.');
    pause(0.1);
end % while true

end % function mazeServer

