%maze_class
classdef mazeClass < handle
    properties
        ndim = 2; % Nunmber of dimensions
        dim = [3 6 1]; % Rows, columns, levels, planes
        rooms = ROOM_TYPE;
        current_room_index = 1;
        room_count = 0;

        % Build variables
        FreeWallList = [];
        NumFreeWall = 0;

        % Build properties
        linearity = 0.9; % 0..1, 1=longer straightaways
        continuous_passage = 0.95; % 0..1, 1=fewer dead ends
        stay_on_level = 0.9; % Reduce level-to-level transitions
        favored_direction = -1; % Used in conjunction with linearity flag

    end % PROPERTIES
    methods
        %---------------------------------------------------------------
        % maze_class - Constructor
        function obj = mazeClass(siz)
            if nargin == 0
                siz = [3 6 1];
            end
            obj.rooms = repmat(ROOM_TYPE,siz);
            obj.room_count = numel(obj.rooms);
            obj.Initialize;
            obj.Build;
        end % function maze_class - Constructor

        %---------------------------------------------------------------
        % Build - Create a random maze
        function Build(obj)
            %rng(1)
            profile clear
            profile on
            obj.FreeWallList = repmat(FREE_WALL_TYPE,1,obj.room_count);
            obj.NumFreeWall = 0;
            % Start at particular room
            obj.current_room_index = 1;
            obj.AddFreeWalls(obj.current_room_index);
            obj.rooms(obj.current_room_index).isUsed = true;

            while obj.NumFreeWall > 0
                % The character of the maze is detemined by how we choose which
                % walls to remove. Options:
                % - Pick a wall that is on the current level/plane. This will
                %   reduce transitions between planes and levels. Controlled by the
                %   stay_on_level parameter.
                % - Pick a wall that leads into the last room opened. This will
                %   tend to make for longer, continuous passages, with fewer dead
                %   ends. Controlled by continuous_passage property.
                % - Pick a wall that is opposite of an open wall. This will tend to
                %   make for longer straighaways. Controlled by the linearity
                %   parameter.
                % Categorize the options
                %free2used_direction = [obj.FreeWallList(1:obj.NumFreeWall).free2used_direction];
                used2free_direction = [obj.FreeWallList(1:obj.NumFreeWall).used2free_direction];
                used_room_index = [obj.FreeWallList(1:obj.NumFreeWall).used_room_index];
                same_level_flags  = used2free_direction == 1 | used2free_direction == 2 | used2free_direction == 5 | used2free_direction == 6;
                same_room_flags = used_room_index == obj.current_room_index;
                same_direction_flags = (used2free_direction == obj.favored_direction) & same_room_flags;
                StayOnSameLevelFlag = rand(1) < obj.stay_on_level && any(same_level_flags);
                ContiuousPassageFlag = rand(1) < obj.continuous_passage && any(same_room_flags);
                % Somes times there will be a conlict. If StayOnSameLevelFlag is
                % true, and ContiuousPassageFlag is true, but there is no other
                % option from the current room to go anywhere except off-level,
                % favor the StayOnSameLevelFlag.
                if ContiuousPassageFlag
                    if StayOnSameLevelFlag
                        CanStayOnSameLevelFlag = any(same_room_flags & same_level_flags);
                    else
                        CanStayOnSameLevelFlag = any(same_room_flags);
                    end
                    ContiuousPassageFlag = CanStayOnSameLevelFlag;
                end
                if ContiuousPassageFlag
                    if StayOnSameLevelFlag
                        same_room_flags = same_room_flags & same_level_flags;
                        same_direction_flags = same_direction_flags & same_level_flags;
                    end
                    if rand(1) < obj.linearity && any(same_direction_flags)
                        % Try to continue in the same direction
                        same_room_flags = same_direction_flags;
                    end
                    f = find(same_room_flags);
                    assert(~isempty(f));
                    wallIndex = f(randi(length(f)));
                else
                    if StayOnSameLevelFlag
                        f = find(same_level_flags);
                        assert(~isempty(f));
                        wallIndex = f(randi(length(f)));
                    else
                        %assert(~isempty(f));
                        wallIndex = randi(obj.NumFreeWall);
                    end
                end


                % Pick a random free wall and delete that wall
                obj.ConnectFreeRoom(wallIndex); % The new room becomes the current room

                %         obj.PlotMazeBuild;
                %         pause
            end
            profile off
            if obj.room_count >= 2500
                profile viewer
            end
            if obj.room_count <= 2500
                obj.PlotMazeBuild
            end

        end % function Build

        %---------------------------------------------------------------

        function ConnectFreeRoom(obj,wallIndex)
            used_room_index = obj.FreeWallList(wallIndex).used_room_index;
            free_room_index = obj.FreeWallList(wallIndex).free_room_index;
            free2used_direction = obj.FreeWallList(wallIndex).free2used_direction;
            used2free_direction = obj.FreeWallList(wallIndex).used2free_direction;
            % Break down a wall
            obj.rooms(free_room_index).wall_flag(free2used_direction) = false;
            obj.rooms(used_room_index).wall_flag(used2free_direction) = false;
            % Remove the free wall
            obj.current_room_index = free_room_index;
            obj.DeleteFreeWalls;
            obj.rooms(obj.current_room_index).isUsed = true;
            obj.AddFreeWalls(obj.current_room_index);
            obj.favored_direction = used2free_direction; % Used with lineary
        end % function ConnectFreeRoomToCurrent

        %---------------------------------------------------------------
        % DeleteFreeWalls - A new room in the maze has been exposed.
        %  Remove any free wall leading into this room.
        function DeleteFreeWalls(obj)
            temp = [obj.FreeWallList(1:obj.NumFreeWall).free_room_index];
            for ii = obj.NumFreeWall:-1:1
                %if obj.FreeWallList(ii).free_room_index == obj.current_room_index
                if temp(ii) == obj.current_room_index
                    obj.FreeWallList(ii) = obj.FreeWallList(obj.NumFreeWall);
                    temp(ii) = temp(obj.NumFreeWall);
                    obj.NumFreeWall = obj.NumFreeWall - 1;
                end
            end % for ii
        end % function DeleteFreeWalls

        %---------------------------------------------------------------
        % AddFreeWalls - A new room in the maze has been exposed.
        %  Determine which adjacent rooms, and the directions from which, lead
        %  to the current room index.
        function AddFreeWalls(obj, used_room_index)
            % Peak in each direction. If there is an unexplored room in that
            % direction, add a "free wall" from that room to the current room
            for dir = DIR.allDirs %1:8
                adjacent_room_index = obj.nextRoom(used_room_index,dir);
                if isnan(adjacent_room_index) % could also used edge_flag
                    continue
                end
                if obj.rooms(adjacent_room_index).isStone
                    continue
                end
                if obj.rooms(adjacent_room_index).isUsed
                    continue
                end
                % Add one free wall
                obj.NumFreeWall = obj.NumFreeWall + 1;
                obj.FreeWallList(obj.NumFreeWall).free_room_index = adjacent_room_index;
                obj.FreeWallList(obj.NumFreeWall).free2used_direction = OppositeDir(dir);
                obj.FreeWallList(obj.NumFreeWall).used_room_index = used_room_index;
                obj.FreeWallList(obj.NumFreeWall).used2free_direction = dir;
            end
        end % function AddFreeWalls

        %---------------------------------------------------------------
        % PlotMazeBuild
        function PlotMazeBuild(obj)
            q = 0.475;
            % 2-D plot, for now
            [rows,cols,levels,planes] = size(obj.rooms);
            assert(planes == 1)
            Zstep = rows*0.5;
            P = 1;
            cla('reset');
            hold on
            axis equal
            set(gca,'YDir','reverse')
            % Create arrays of plot data. Plotting one large set (interspersed
            % with NaNs) is much faster than a multiple of individual line
            % segments.
            walls1_xyz = inf(3*4*obj.room_count,4);walls1_count = 0;
            walls2_xyz = nan(3*4*obj.room_count,4);walls2_count = 0;
            for R = 1:rows
                for C = 1:cols
                    for L = 1:levels
                        zUp = (L-1) * Zstep;
                        index = obj.pos2ind(R,C,L,P);
                        if rows*cols <= 100
                            text(C,R,zUp,num2str(index),'VerticalAlignment','middle','HorizontalAlignment','center');
                        end
                        if obj.rooms(index).isUsed
                            symb = 'k-';
                        else
                            symb = 'y-';
                        end
                        [~,isWall] = obj.nextRoom(index,1,1); % South
                        if isWall
                            local_add_wall_segment(C + q*[-1,1],R + q*[1 1],zUp)
                            %plot(C + q*[-1,1],R + q*[1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,1,-1); % North
                        if isWall
                            local_add_wall_segment(C + q*[-1,1],R - q*[1 1],zUp);
                            %plot(C + q*[-1,1],R - q*[1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,2,1); % East
                        if isWall
                            local_add_wall_segment(C + q*[1,1],R + q*[-1 1],zUp);
                            %plot(C + q*[1,1],R + q*[-1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,2,-1); % West
                        if isWall
                            local_add_wall_segment(C - q*[1,1],R + q*[-1 1],zUp);
                            %plot(C - q*[1,1],R + q*[-1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,3,1); % Up
                        if ~isWall
                            plot3(C*[1,1],R*[1,1],zUp+[0 Zstep],'c-');
                        end
                    end % for L
                end % for C
            end % for R

            function local_add_wall_segment(xx,yy,zz)
                walls1_xyz(walls1_count+(1:2),1) = xx;
                walls1_xyz(walls1_count+(1:2),2) = yy;
                walls1_xyz(walls1_count+(1:2),3) = zz;
                walls1_xyz(walls1_count+(1:3),4) = obj.rooms(index).isUsed;
                walls1_count = walls1_count + 3;
            end

            % Plot all the walls at once
            sel = walls1_xyz(:,4) == 1;
            plot3(walls1_xyz(sel,1)',walls1_xyz(sel,2)',walls1_xyz(sel,3)','k-');
            sel = walls1_xyz(:,4) == 0;
            plot3(walls1_xyz(sel,1)',walls1_xyz(sel,2)',walls1_xyz(sel,3)','y-');


            % Plot the free walls
            for ii=1:obj.NumFreeWall
                W = obj.FreeWallList(ii);
                [R,C,L,P] = ind2sub(size(obj.rooms),W.used_room_index);
                zUp = (L-1) * Zstep;
                switch W.used2free_direction
                    case 1, y = +1; x = 0; z = 0;
                    case 5, y = -1; x = 0; z = 0;
                    case 2, y = 0; x = +1; z = 0;
                    case 6, y = 0; x = -1; z = 0;
                    case 3, y = 0; x = 0; z = 1;
                    case 7, y = 0; x = 0; z = -1;
                    otherwise, error
                end
                plot3(C + q*x, R + q*y, zUp + q*z, 'go');
                [R,C,L,P] = ind2sub(size(obj.rooms),W.free_room_index);
                zUp = (L-1) * Zstep;
                switch W.free2used_direction
                    case 1, y = +1; x = 0; z = 0; symb = 'rv';
                    case 5, y = -1; x = 0; z = 0; symb = 'r^';
                    case 2, y = 0; x = +1; z = 0; symb = 'r>';
                    case 6, y = 0; x = -1; z = 0; symb = 'r<';
                    case 3, y = 0; x = 0; z = 1; symb = 'r^';
                    case 7, y = 0; x = 0; z = -1; symb = 'rv';
                    otherwise, error
                end
                plot3(C + q*x, R + q*y, zUp + q*z, symb);

            end % for ii

            hold off
            set(gca,'YLim',[0.5,rows+0.5],'XLim',[0.5,cols+0.5]);
            view(-30,22);

        end % function PlotMazeBuild

        %---------------------------------------------------------------
        % Initialize - Build a maze with all walls defined
        function Initialize(obj)
            % The rooms array must already have been built
            [rows,cols,levels,planes] = size(obj.rooms);

            for R = 1:rows
                for C = 1:cols
                    for L = 1:levels
                        for P = 1:planes
                            index = obj.pos2ind(R,C,L,P);
                            assert(~isnan(index))
                            obj.rooms(index).index = index;
                            obj.rooms(index).position = [R,C,L,P];
                            obj.rooms(index).wall_flag = true(4,2);
                            % Describe how to get from current room to each adjacent
                            % room, in all eight cardinal directions
                            next_room_index = obj.pos2ind(...
                                R + [1,-1;0,0;0,0;0,0], ... Row (+S, -N)
                                C + [0,0;1,-1;0,0;0,0], ... Col (+E, -W)
                                L + [0,0;0,0;1,-1;0,0], ... Level (+Up, -Down)
                                P + [0,0;0,0;0,0;1,-1]); ... Plane (+, -)
                                obj.rooms(index).next_room_index = next_room_index;
                            obj.rooms(index).edge_flag = isnan(next_room_index);
                            obj.rooms(index).isUsed = false;
                            obj.rooms(index).isStone = false;
                        end % for P
                    end % for L
                end % for C
            end % for R

        end % function Initialize

        %---------------------------------------------------------------
        %pos2ind - Convert a position (row,col,lvl,plane) into a scalar index.
        %  Each positional element can be an array.
        function index = pos2ind(obj,R,C,L,P)
            [rows,cols,levels,planes] = size(obj.rooms);
            good = ...
                R >= 1 & R <= rows & ...
                C >= 1 & C <= cols & ...
                L >= 1 & L <= levels & ...
                P >= 1 & P <= planes;
            index = R + (C-1)*rows + (L-1)*rows*cols + (P-1)*rows*cols*levels;
            index(~good) = nan;
        end % function pos2ind

        %---------------------------------------------------------------
        %nextRoom - From current room, determine the adjacent room index in
        %  the specified direction. Returns NaN if there is no move in that
        %  direction.
        % nextRoom(dim,direction) - dim 1..4, direction is +1 or -1
        % nextRoom(dim) - dim is 1..8
        % INPUTS:
        %   dim - Index of the movement direction:
        %     1 - Row (+S, -N)
        %     2 - Col (+E, -W)
        %     3 - Level (+Up, -Down)
        %     4 - Plane (+, -)
        %   direction
        %     +1 - Move S, E, Up or +plane
        %     -1 - Move N, W, Down or -plane
        % OUTPUTS:
        %   index - The index of the adjacent room in the specified direction
        %   isWall - True, if there is a maze wall blocking that direction
        function [index,isWall] = nextRoom(obj,room_index,dim,direction)
            if nargin == 4
                assert(ismember(dim,1:4));
                assert(ismember(direction,[+1,-1]));
                switch direction
                    case +1, col = 1;
                    case -1, col = 2;
                end
                index = obj.rooms(room_index).next_room_index(dim,col);
                isWall = obj.rooms(room_index).wall_flag(dim,col);
            elseif nargin == 3
                assert(ismember(dim,1:8));
                index = obj.rooms(room_index).next_room_index(dim);
                isWall = obj.rooms(room_index).wall_flag(dim);
            end
        end % function nextRoom

        %-------------------------------------------------------------------
        function design = getDesign(obj,args)
            arguments
                obj(1,1) mazeClass
                args.format(1,1) string {mustBeMember(args.format,["raw","json"])} = raw
            end % arguments

            switch args.format
                case "raw"
                    design = obj.rooms;
                case "json"
                    txt = jsonencode(obj.rooms,'PrettyPrint',true);
                    design = txt;
            end % switch args.format

        end % function getDesign

        %-------------------------------------------------------------------
        function setDesign(obj,design)

            arguments
                obj(1,1) mazeClass
                design
            end

            if isstruct(design)
                my_rooms = design;
            elseif ischar(design) || isstring(design)
                my_rooms = jsondecode(design);
            else
                error('invalid design argument')
            end

            obj.rooms = my_rooms;
            obj.room_count = numel(my_rooms);
            obj.ndim = ndims(my_rooms);
            obj.dim = size(my_rooms,[1 2 3]);
            obj.current_room_index = 1;

        end % function setDesign

        %-------------------------------------------------------------------
        % drawFirstPersonPerspective
        function drawFirstPersonPerspective(obj)
            % drawFirstPersonPerspective - Draw the maze from the first person point of view
            q = 0.475;
            % 2-D plot, for now
            [rows,cols,levels,planes] = size(obj.rooms);
            assert(planes == 1)
            Zstep = rows*0.5;
            P = 1;
            cla('reset');
            hold on
            axis equal
            set(gca,'YDir','reverse')
            % Create arrays of plot data. Plotting one large set (interspersed
            % with NaNs) is much faster than a multiple of individual line
            % segments.
            walls1_xyz = inf(3*4*obj.room_count,4);walls1_count = 0;
            walls2_xyz = nan(3*4*obj.room_count,4);walls2_count = 0;
            for R = 1:rows
                for C = 1:cols
                    for L = 1:levels
                        zUp = (L-1) * Zstep;
                        index = obj.pos2ind(R,C,L,P);
                        if rows*cols <= 100
                            text(C,R,zUp,num2str(index),'VerticalAlignment','middle','HorizontalAlignment','center');
                        end
                        if obj.rooms(index).isUsed
                            symb = 'k-';
                        else
                            symb = 'y-';
                        end
                        index = obj.pos2ind(R,C,L,P);
                        [~,isWall] = obj.nextRoom(index,1,1); % South
                        if isWall
                            x = [0 1 1 0];
                            y = [1 1 1 1];
                            z = [0 0 1 1];
                            patch(C+x - 0.5,R+y - 0.5,zUp + z,'blue','Clipping','off')
                            %plot(C + q*[-1,1],R + q*[1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,1,-1); % North
                        if isWall
                            x = [0 1 1 0];
                            y = [0 0 0 0];
                            z = [0 0 1 1];
                            patch(C+x - 0.5,R+y - 0.5,zUp + z,'blue','Clipping','off')
                            local_add_wall_segment(C + q*[-1,1],R - q*[1 1],zUp);
                            %plot(C + q*[-1,1],R - q*[1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,2,1); % East
                        if isWall
                            x = [1 1 1 1];
                            y = [0 1 1 0];
                            z = [0 0 1 1];
                            patch(C+x - 0.5,R+y - 0.5,zUp + z,'blue','Clipping','off')
                            local_add_wall_segment(C + q*[1,1],R + q*[-1 1],zUp);
                            %plot(C + q*[1,1],R + q*[-1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,2,-1); % West
                        if isWall
                            x = [0 0 0 0];
                            y = [0 1 1 0];
                            z = [0 0 1 1];
                            patch(C+x - 0.5,R+y - 0.5,zUp + z,'blue','Clipping','off')
                            local_add_wall_segment(C - q*[1,1],R + q*[-1 1],zUp);
                            %plot(C - q*[1,1],R + q*[-1 1],symb,'ZData',zUp * [1 1]);
                        end
                        [~,isWall] = obj.nextRoom(index,3,1); % Up
                        if ~isWall
                            plot3(C*[1,1],R*[1,1],zUp+[0 Zstep],'c-');
                        end
                    end % for L
                end % for C
            end % for R

            function local_add_wall_segment(xx,yy,zz)
                walls1_xyz(walls1_count+(1:2),1) = xx;
                walls1_xyz(walls1_count+(1:2),2) = yy;
                walls1_xyz(walls1_count+(1:2),3) = zz;
                walls1_xyz(walls1_count+(1:3),4) = obj.rooms(index).isUsed;
                walls1_count = walls1_count + 3;
            end

            % Plot all the walls at once
            sel = walls1_xyz(:,4) == 1;
            plot3(walls1_xyz(sel,1)',walls1_xyz(sel,2)',walls1_xyz(sel,3)','k-');
            sel = walls1_xyz(:,4) == 0;
            plot3(walls1_xyz(sel,1)',walls1_xyz(sel,2)',walls1_xyz(sel,3)','y-');

            hold off
            set(gca,'YLim',[0.5,rows+0.5],'XLim',[0.5,cols+0.5]);
            % view(-30,22);
            campos([1 1 1.1])
            camva(30)
            camtarget([2 1 1.1])
            camproj('perspective')

        end % function drawFirstPersonPerspective

    end % methods

end % classdef

%---------------------------------------------------------------
% OppositeDir
function dir_out = OppositeDir(dir_in)
switch class(dir_in)
    case 'double', d = DIR(dir_in);
    case 'DIR', d = dir_in;
end
dir_out = d.volte;
% switch dir_in
%   case 1, dir_out = 5; % S -> N
%   case 2, dir_out = 6; % E -> W
%   case 3, dir_out = 7; % Up -> Dn
%   case 4, dir_out = 8; %  -> plane
%   case 5, dir_out = 1; % N -> S
%   case 6, dir_out = 2; % W -> E
%   case 7, dir_out = 3; % Dn -> Up
%   case 8, dir_out = 4; %  -> plane
%   otherwise, error %#ok<LTARG>
% end
end % function OppositeDir

%---------------------------------------------------------------
% FREE_WALL_TYPE - Describes how one wall from an unused (free) room can be
%   opened to a used room. One unused room may have several adjacent to
%   used rooms. Likewise a used room may have walls from multiple unused
%   adjacent rooms.
%   FREE_WALL_TYPE is used only during construction of the maze.
function s = FREE_WALL_TYPE
s = struct(...
    'free_room_index', nan, ... % Index of an unused room
    'free2used_direction', nan, ... % Direction to an used rooms
    'used_room_index', nan, ... % Index of an adjacent used room
    'used2free_direction', nan); % How to get back
end % function FREE_WALL_TYPE

%---------------------------------------------------------------
% ROOM_TYPE - Describes each room or cell within the maze:
%   what other rooms it connects to, etc.
function s = ROOM_TYPE
% These 4 x 2 matrices indicate direction properties from within a
% room. The four dimesions are:
%  [1] - Row (+S, -N)
%  [2] - Col (+E, -W)
%  [3] - Level (+Up, -Down)
%  [4] - Plane (+, -)
s = struct(...
    'index', 1, ... % Room index
    'edge_flag', false(4,2), ... % At maze edge? dim x direction
    'wall_flag', true(4,2), ... % wall blocks travel? dim x direction
    'next_room_index', nan(4,2), ... % Which room does each direction take us too?
    'isUsed', false, ... % Weather this room has been added to the maze paths
    'isStone', false); % Set to true to prevent this room from becoming part of the maze path.
end % function ROOM_TYPE

