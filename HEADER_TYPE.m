function s = HEADER_TYPE(messageType,byteCount)
% HEADER_TYPE - Structure template for transferring data over socket, with
% fixed number of bytes.

arguments
    messageType(1,1) MESSAGE_ENUM_TYPE = MESSAGE_ENUM_TYPE.MT_EMPTY
    byteCount(1,1) int32 = 0
end % arguments

s = struct( ...
    'messageType', int32(messageType), ...
    'byteCount', byteCount);

end % function HEADER_TYPE

