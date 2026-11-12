classdef CServerFreeBlenderPyCommManager < BlenderPyCommManager
    %% DESCRIPTION
    % Exercise camera configuration without probing or connecting to a Blender server.
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 18-10-2026  Pietro Califano, Codex GPT-6.1  Add a CPU-only camera boundary fixture.
    % 12-11-2026  Pietro Califano, Claude Opus 5.5  Readability pass.
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % BlenderPyCommManager.
    % -------------------------------------------------------------------------------------------------------------

    methods
        function self = CServerFreeBlenderPyCommManager(varargin)
            %% SIGNATURE
            % self = CServerFreeBlenderPyCommManager(varargin)
            % -------------------------------------------------------------------------------------------------
            %% DESCRIPTION
            % Forward constructor options while leaving communication and automatic server management disabled.
            % -------------------------------------------------------------------------------------------------
            %% INPUT
            % varargin    Camera and YAML options accepted by BlenderPyCommManager.
            % -------------------------------------------------------------------------------------------------
            %% OUTPUT
            % self        Server-free camera consumer fixture.
            % -------------------------------------------------------------------------------------------------
            %% CHANGELOG
            % 18-10-2026  Pietro Califano, Codex GPT-6.1  Add a CPU-only camera boundary fixture.
            % -------------------------------------------------------------------------------------------------
            %% DEPENDENCIES
            % BlenderPyCommManager.
            % -------------------------------------------------------------------------------------------------
            arguments (Input, Repeating)
                varargin
            end
            arguments (Output)
                self (1,1) CServerFreeBlenderPyCommManager
            end

            % Disable connection at construction and automatic server management.
            self = self@BlenderPyCommManager(varargin{:}, ...
                'bInitInPlace', false, ...
                'bAutoManageBlenderServer', false);
        end

        function bIsServerRunning = checkRunningBlenderServer(~)
            %% SIGNATURE
            % bIsServerRunning = checkRunningBlenderServer(self)
            % -------------------------------------------------------------------------------------------------
            %% DESCRIPTION
            % Permit configuration writes without probing external processes.
            % -------------------------------------------------------------------------------------------------
            %% INPUT
            % self                Server-free fixture.
            % -------------------------------------------------------------------------------------------------
            %% OUTPUT
            % bIsServerRunning    False; no server is inspected or contacted.
            % -------------------------------------------------------------------------------------------------
            %% CHANGELOG
            % 18-10-2026  Pietro Califano, Codex GPT-6.1  Isolate camera tests from live servers.
            % -------------------------------------------------------------------------------------------------
            %% DEPENDENCIES
            % None.
            % -------------------------------------------------------------------------------------------------
            arguments (Output)
                bIsServerRunning (1,1) logical
            end

            bIsServerRunning = false;
        end
    end
end
