classdef DIR < int32
    % DIR - An enumeration class to define the 8 cardinal directions in four dimensional space:
    %   East X+ (positive X direction)
    %   West X- (negative X direction)
    %   North Y- (positive Y direction) Note sign reversal, to match a matrix layout
    %   South Y+ (negative Y direction)
    %   Up Z+ (positive Z direction)
    %   Down Z- (negative Z direction)
    %   Ana W+ (positive W direction)
    %   Kata W- (negative W direction)
    enumeration
        South(1)
        East(2)
        Up(3)
        Ana(4)
        North(5)
        West(6)
        Down(7)
        Kata(8)
    end

    methods
        %---------------------------------------------------------------
        % volte
        function reverseDir = volte(me)
            % volte - Return the opposite direction. For French voltare ("to turn"), as in volte-face.
            arguments (Input)
                me(1,1) DIR
            end
            arguments (Output)
                reverseDir(1,1) DIR
            end
            switch me
                case DIR.South, reverseDir = DIR.North;
                case DIR.East, reverseDir = DIR.West;
                case DIR.Up, reverseDir = DIR.Down;
                case DIR.Ana, reverseDir = DIR.Kata;
                case DIR.North, reverseDir = DIR.South;
                case DIR.West, reverseDir = DIR.East;
                case DIR.Down, reverseDir = DIR.Up;
                case DIR.Kata, reverseDir = DIR.Ana;
            end % switch me
        
        end % function volte

        %---------------------------------------------------------------
        % toXYZW
        function [x,y,z,w] = toXYZW(me)
            % toXYZW - Return the cartesion unit vector in specifed direction
            %   [x,y,z,w] = toXYZW(me)
            % -- or --
            %   [xyzw] = toXYZW(me)
            arguments (Input)
                me(1,1) DIR
            end
            switch me
                case DIR.South, y = +1; x =  0; z =  0; w =  0;
                case DIR.North, y = -1; x =  0; z =  0; w =  0;
                case DIR.East , y =  0; x = +1; z =  0; w =  0;
                case DIR.West , y =  0; x = -1; z =  0; w =  0;
                case DIR.Up   , y =  0; x =  0; z = +1; w =  0;
                case DIR.Down , y =  0; x =  0; z = -1; w =  0;
                case DIR.Ana  , y =  0; x =  0; z =  0; w = +1;
                case DIR.Kata , y =  0; x =  0; z =  0; w = -1;
            end % switch me
            xyzw = [x,y,z,w];
            if nargout < 2
                x = xyzw;
            end

        end % function toXYZW

    end % methods

    methods (Static)
        function list = allDirs
            list = [
                DIR.South, ...
                DIR.East, ...
                DIR.Up, ...
                DIR.Ana, ...
                DIR.North, ...
                DIR.West, ...
                DIR.Down, ...
                DIR.Kata ];
        end
    end % methods (Static)
end % classdef

