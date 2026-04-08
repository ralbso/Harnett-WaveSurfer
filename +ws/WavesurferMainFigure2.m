classdef WavesurferMainFigure2 < ws.AppFigure
    % WavesurferMainFigure2 — Modern uifigure-based main window for WaveSurfer.
    %
    % Replaces the old WavesurferMainFigure (figure-based) + WavesurferMainController
    % with a single unified class using uifigure, uigridlayout, and uiaxes.
    %
    % This is the Phase 4 proof-of-concept. Other windows follow the same pattern.
    
    properties (Access = protected)
        % --- Toolbar controls ---
        ToolbarGrid_
        PlayButton_
        RecordButton_
        StopButton_
        FastProtocolButtons_
        ManageFastProtocolsButton_
        
        % --- Menu bar ---
        FileMenu_
        ToolsMenu_
        ViewMenu_
        HelpMenu_
        
        % --- Scope area ---
        ScopeGrid_
        ScopeAxes_           % array of uiaxes, one per plot
        ScopeLines_          % cell array of animatedline objects
        
        % --- Status bar ---
        StatusGrid_
        StatusLabel_
        ProgressBar_         % MATLAB uiprogressdlg or custom gauge
        
        % --- Data caches for streaming ---
        XData_
        YData_
        
        % --- Subsidiary figure references ---
        ChannelsFigure_
        GeneralSettingsFigure_
        StimulusLibraryFigure_
        TriggersFigure_
        ElectrodeManagerFigure_
        TestPulserFigure_
        FastProtocolsFigure_
        UserCodeManagerFigure_
    end
    
    methods
        function self = WavesurferMainFigure2(model)
            self@ws.AppFigure(model, 'WaveSurfer', [900 650]) ;
            
            % Subscribe to model events
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateChannels', '', 'update') ;
                model.subscribeMe(self, 'DidChangeNumberOfInputChannels', '', 'updateScopePlots') ;
                model.subscribeMe(self, 'UpdateForNewData', '', 'updateForNewData') ;
                model.subscribeMe(self, 'DidCompleteSweep', '', 'updateControlProperties') ;
                model.subscribeMeToDisplayEvent(self, 'ClearData', '', 'clearData') ;
                model.subscribeMeToDisplayEvent(self, 'AddData', '', 'addData') ;
                model.subscribeMeToDisplayEvent(self, 'UpdateXOffset', '', 'updateXAxisLimits') ;
            end
            
            % Initial sync
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            % Configure root grid: toolbar | scope area | status bar
            self.GridLayout_.RowHeight = {36, '1x', 28} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            
            self.createToolbar_() ;
            self.createScopeArea_() ;
            self.createStatusBar_() ;
            self.createMenuBar_() ;
        end
        
        function createToolbar_(self)
            self.ToolbarGrid_ = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {60, 60, 60, 20, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 10, 'fit', '1x'}, ...
                'Padding', [5 2 5 2], ...
                'ColumnSpacing', 4) ;
            self.ToolbarGrid_.Layout.Row = 1 ;
            self.ToolbarGrid_.Layout.Column = 1 ;
            
            self.PlayButton_ = uibutton(self.ToolbarGrid_, ...
                'Text', 'Play', ...
                'Icon', '', ...
                'ButtonPushedFcn', @(~,~) self.playButtonPushed_()) ;
            self.PlayButton_.Layout.Column = 1 ;
            
            self.RecordButton_ = uibutton(self.ToolbarGrid_, ...
                'Text', 'Record', ...
                'Icon', '', ...
                'ButtonPushedFcn', @(~,~) self.recordButtonPushed_()) ;
            self.RecordButton_.Layout.Column = 2 ;
            
            self.StopButton_ = uibutton(self.ToolbarGrid_, ...
                'Text', 'Stop', ...
                'Icon', '', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) self.stopButtonPushed_()) ;
            self.StopButton_.Layout.Column = 3 ;
            
            % Fast protocol buttons
            nFP = 6 ;
            self.FastProtocolButtons_ = gobjects(1, nFP) ;
            for i = 1:nFP
                self.FastProtocolButtons_(i) = uibutton(self.ToolbarGrid_, ...
                    'Text', sprintf('F%d', i), ...
                    'ButtonPushedFcn', @(~,~) self.fastProtocolButtonPushed_(i)) ;
                self.FastProtocolButtons_(i).Layout.Column = 4 + i ;
            end
            
            self.ManageFastProtocolsButton_ = uibutton(self.ToolbarGrid_, ...
                'Text', 'Manage...', ...
                'ButtonPushedFcn', @(~,~) self.manageFastProtocolsPushed_()) ;
            self.ManageFastProtocolsButton_.Layout.Column = 12 ;
        end
        
        function createScopeArea_(self)
            % The scope area is a grid that will hold one uiaxes per active channel.
            % It starts empty and is rebuilt when channels change.
            self.ScopeGrid_ = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [4 4 4 4]) ;
            self.ScopeGrid_.Layout.Row = 2 ;
            self.ScopeGrid_.Layout.Column = 1 ;
            
            self.ScopeAxes_ = gobjects(0) ;
            self.ScopeLines_ = {} ;
        end
        
        function createStatusBar_(self)
            self.StatusGrid_ = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x', 150}, ...
                'Padding', [8 2 8 2]) ;
            self.StatusGrid_.Layout.Row = 3 ;
            self.StatusGrid_.Layout.Column = 1 ;
            
            self.StatusLabel_ = uilabel(self.StatusGrid_, ...
                'Text', 'Idle', ...
                'FontSize', 11) ;
            self.StatusLabel_.Layout.Column = 1 ;
            
            % Simple gauge-based progress indicator
            self.ProgressBar_ = uigauge(self.StatusGrid_, 'linear', ...
                'Limits', [0 1], ...
                'Value', 0, ...
                'ScaleColors', {'#4CAF50'}, ...
                'ScaleColorLimits', [0 1]) ;
            self.ProgressBar_.Layout.Column = 2 ;
        end
        
        function createMenuBar_(self)
            fig = self.Figure_ ;
            
            % --- File menu ---
            self.FileMenu_ = uimenu(fig, 'Text', 'File') ;
            uimenu(self.FileMenu_, 'Text', 'Open Protocol...', ...
                'Accelerator', 'O', ...
                'MenuSelectedFcn', @(~,~) self.openProtocol_()) ;
            uimenu(self.FileMenu_, 'Text', 'Save Protocol', ...
                'Accelerator', 'S', ...
                'MenuSelectedFcn', @(~,~) self.saveProtocol_()) ;
            uimenu(self.FileMenu_, 'Text', 'Save Protocol As...', ...
                'MenuSelectedFcn', @(~,~) self.saveProtocolAs_()) ;
            uimenu(self.FileMenu_, 'Text', 'Quit', ...
                'Separator', 'on', ...
                'Accelerator', 'Q', ...
                'MenuSelectedFcn', @(~,~) self.quitRequested_()) ;
            
            % --- Tools menu ---
            self.ToolsMenu_ = uimenu(fig, 'Text', 'Tools') ;
            uimenu(self.ToolsMenu_, 'Text', 'Channels...', ...
                'MenuSelectedFcn', @(~,~) self.showChannelsFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'General Settings...', ...
                'MenuSelectedFcn', @(~,~) self.showGeneralSettingsFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'Triggers...', ...
                'MenuSelectedFcn', @(~,~) self.showTriggersFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'Stimulus Library...', ...
                'MenuSelectedFcn', @(~,~) self.showStimulusLibraryFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'User Code...', ...
                'MenuSelectedFcn', @(~,~) self.showUserCodeFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'Electrodes...', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) self.showElectrodesFigure_()) ;
            uimenu(self.ToolsMenu_, 'Text', 'Test Pulse...', ...
                'MenuSelectedFcn', @(~,~) self.showTestPulseFigure_()) ;
            
            % --- View menu ---
            self.ViewMenu_ = uimenu(fig, 'Text', 'View') ;
            uimenu(self.ViewMenu_, 'Text', 'Show Grid', ...
                'MenuSelectedFcn', @(~,~) self.toggleGrid_()) ;
            uimenu(self.ViewMenu_, 'Text', 'Invert Colors', ...
                'MenuSelectedFcn', @(~,~) self.toggleInvertColors_()) ;
            
            % --- Help menu ---
            self.HelpMenu_ = uimenu(fig, 'Text', 'Help') ;
            uimenu(self.HelpMenu_, 'Text', 'About WaveSurfer...', ...
                'MenuSelectedFcn', @(~,~) self.showAbout_()) ;
        end
        
        % =====================================================================
        % Update implementations
        % =====================================================================
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            % Status text
            state = model.State ;
            switch state
                case 'idle'
                    statusText = 'Idle' ;
                case 'running'
                    nDone = model.NSweepsCompletedInThisRun ;
                    nTotal = model.NSweepsPerRun ;
                    if isinf(nTotal)
                        statusText = sprintf('Running (sweep %d, continuous)', nDone + 1) ;
                    else
                        statusText = sprintf('Running (sweep %d of %d)', nDone + 1, nTotal) ;
                    end
                case 'no_device'
                    statusText = 'No device' ;
                otherwise
                    statusText = state ;
            end
            self.StatusLabel_.Text = statusText ;
            
            % Progress bar
            if strcmp(state, 'running') && ~isinf(model.NSweepsPerRun)
                self.ProgressBar_.Value = model.NSweepsCompletedInThisRun / model.NSweepsPerRun ;
            else
                self.ProgressBar_.Value = 0 ;
            end
            
            % Fast protocol button tooltips
            for i = 1:min(6, length(self.FastProtocolButtons_))
                fp = model.FastProtocols{i} ;
                if ~isempty(fp.ProtocolFileName) && ~isempty(fp.ProtocolFileName)
                    self.FastProtocolButtons_(i).Tooltip = fp.ProtocolFileName ;
                else
                    self.FastProtocolButtons_(i).Tooltip = sprintf('Fast Protocol %d (empty)', i) ;
                end
            end
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            isIdle = isequal(model.State, 'idle') ;
            isRunning = isequal(model.State, 'running') ;
            hasDevice = ~isequal(model.State, 'no_device') ;
            
            self.PlayButton_.Enable = ws.onIff(isIdle && hasDevice) ;
            self.RecordButton_.Enable = ws.onIff(isIdle && hasDevice) ;
            self.StopButton_.Enable = ws.onIff(isRunning) ;
        end
        
        % =====================================================================
        % Scope plot management
        % =====================================================================
        function updateScopePlots(self, varargin)
            % Rebuild the scope axes when channels change.
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            % Delete existing axes
            for i = 1:length(self.ScopeAxes_)
                if isvalid(self.ScopeAxes_(i))
                    delete(self.ScopeAxes_(i)) ;
                end
            end
            self.ScopeAxes_ = gobjects(0) ;
            self.ScopeLines_ = {} ;
            
            % Determine active channels
            nAI = model.getNActiveAIChannels() ;
            nDI = model.getNActiveDIChannels() ;
            nPlots = nAI + nDI ;
            
            if nPlots == 0
                self.ScopeGrid_.RowHeight = {'1x'} ;
                return
            end
            
            % Configure grid for N plots stacked vertically
            rowHeights = repmat({'1x'}, 1, nPlots) ;
            self.ScopeGrid_.RowHeight = rowHeights ;
            
            % Create axes
            self.ScopeAxes_ = gobjects(1, nPlots) ;
            self.ScopeLines_ = cell(1, nPlots) ;
            
            for i = 1:nPlots
                ax = uiaxes(self.ScopeGrid_) ;
                ax.Layout.Row = i ;
                ax.Layout.Column = 1 ;
                ax.XGrid = 'on' ;
                ax.YGrid = 'on' ;
                ax.Box = 'on' ;
                ax.FontSize = 9 ;
                
                if i < nPlots
                    ax.XTickLabel = {} ;  % hide x labels except bottom
                end
                
                % Create an animated line for streaming data
                al = animatedline(ax, 'Color', [0.2 0.6 1.0], 'LineWidth', 0.5) ;
                
                self.ScopeAxes_(i) = ax ;
                self.ScopeLines_{i} = al ;
            end
            
            % Clear data caches
            self.XData_ = zeros(0, 1) ;
            self.YData_ = zeros(0, nPlots) ;
        end
        
        % =====================================================================
        % Data streaming callbacks
        % =====================================================================
        function addData(self, broadcaster, eventName, propertyName, source, event) %#ok<INUSL>
            % Called by Display subsystem when new data arrives.
            if nargin >= 6 && ~isempty(event) && iscell(event.Args) && length(event.Args) >= 3
                t = event.Args{1} ;
                scaledAnalogData = event.Args{2} ;
                rawDigitalData = event.Args{3} ;
                self.addData_(t, scaledAnalogData, rawDigitalData) ;
            end
        end
        
        function clearData(self, varargin)
            % Clear all scope traces
            for i = 1:length(self.ScopeLines_)
                if ~isempty(self.ScopeLines_{i}) && isvalid(self.ScopeLines_{i})
                    clearpoints(self.ScopeLines_{i}) ;
                end
            end
            self.XData_ = zeros(0, 1) ;
            nPlots = length(self.ScopeLines_) ;
            self.YData_ = zeros(0, nPlots) ;
        end
        
        function updateForNewData(self, varargin)
            % Trigger a drawnow to flush animated line updates
            drawnow('limitrate') ;
        end
        
        function updateXAxisLimits(self, varargin)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            xSpan = model.XSpan ;
            xOffset = model.XOffset ;
            for i = 1:length(self.ScopeAxes_)
                if isvalid(self.ScopeAxes_(i))
                    self.ScopeAxes_(i).XLim = [xOffset, xOffset + xSpan] ;
                end
            end
        end
        
        % =====================================================================
        % Button callbacks (merged from WavesurferMainController)
        % =====================================================================
        function playButtonPushed_(self)
            try
                self.Model_.do('play') ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function recordButtonPushed_(self)
            try
                self.Model_.do('record') ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function stopButtonPushed_(self)
            try
                self.Model_.do('stop') ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function fastProtocolButtonPushed_(self, index)
            try
                self.Model_.do('startLoggingRunFromFastProtocol', index) ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function manageFastProtocolsPushed_(self)
            if isempty(self.FastProtocolsFigure_) || ~isvalid(self.FastProtocolsFigure_)
                self.FastProtocolsFigure_ = ws.FastProtocolsFigure2(self.Model_) ;
            else
                self.FastProtocolsFigure_.raise() ;
            end
        end
        
        % --- Menu callbacks ---
        function openProtocol_(self)
            initialFolder = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;
            [fileName, pathName] = uigetfile({'*.wsp;*.cfg', 'WaveSurfer Protocol Files'}, ...
                                              'Open Protocol', initialFolder) ;
            if ~isequal(fileName, 0)
                fullPath = fullfile(pathName, fileName) ;
                try
                    self.Model_.openProtocolFileGivenFileName(fullPath) ;
                    ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', pathName) ;
                catch me
                    ws.raiseDialogOnException(me) ;
                end
                self.update() ;
            end
        end
        
        function saveProtocol_(self)
            try
                self.Model_.saveProtocolFile() ;
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function saveProtocolAs_(self)
            initialFolder = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;
            [fileName, pathName] = uiputfile({'*.wsp', 'WaveSurfer Protocol'}, ...
                                              'Save Protocol As', initialFolder) ;
            if ~isequal(fileName, 0)
                fullPath = fullfile(pathName, fileName) ;
                try
                    self.Model_.saveProtocolFileGivenFileName(fullPath) ;
                    ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', pathName) ;
                catch me
                    ws.raiseDialogOnException(me) ;
                end
            end
        end
        
        function quitRequested_(self)
            self.Model_.do('quit') ;
        end
        
        function showChannelsFigure_(self)
            if isempty(self.ChannelsFigure_) || ~isvalid(self.ChannelsFigure_)
                self.ChannelsFigure_ = ws.ChannelsFigure2(self.Model_) ;
            else
                self.ChannelsFigure_.raise() ;
            end
        end
        
        function showGeneralSettingsFigure_(self)
            if isempty(self.GeneralSettingsFigure_) || ~isvalid(self.GeneralSettingsFigure_)
                self.GeneralSettingsFigure_ = ws.GeneralSettingsFigure2(self.Model_) ;
            else
                self.GeneralSettingsFigure_.raise() ;
            end
        end
        
        function showTriggersFigure_(self)
            if isempty(self.TriggersFigure_) || ~isvalid(self.TriggersFigure_)
                self.TriggersFigure_ = ws.TriggersFigure2(self.Model_) ;
            else
                self.TriggersFigure_.raise() ;
            end
        end
        
        function showStimulusLibraryFigure_(self)
            if isempty(self.StimulusLibraryFigure_) || ~isvalid(self.StimulusLibraryFigure_)
                self.StimulusLibraryFigure_ = ws.StimulusLibraryFigure2(self.Model_) ;
            else
                self.StimulusLibraryFigure_.raise() ;
            end
        end
        
        function showUserCodeFigure_(self)
            if isempty(self.UserCodeManagerFigure_) || ~isvalid(self.UserCodeManagerFigure_)
                self.UserCodeManagerFigure_ = ws.UserCodeManagerFigure2(self.Model_) ;
            else
                self.UserCodeManagerFigure_.raise() ;
            end
        end
        
        function showElectrodesFigure_(self)
            if isempty(self.ElectrodeManagerFigure_) || ~isvalid(self.ElectrodeManagerFigure_)
                self.ElectrodeManagerFigure_ = ws.ElectrodeManagerFigure2(self.Model_) ;
            else
                self.ElectrodeManagerFigure_.raise() ;
            end
        end
        
        function showTestPulseFigure_(self)
            if isempty(self.TestPulserFigure_) || ~isvalid(self.TestPulserFigure_)
                self.TestPulserFigure_ = ws.TestPulserFigure2(self.Model_) ;
            else
                self.TestPulserFigure_.raise() ;
            end
        end
        
        function toggleGrid_(self)
            for i = 1:length(self.ScopeAxes_)
                if isvalid(self.ScopeAxes_(i))
                    if strcmp(self.ScopeAxes_(i).XGrid, 'on')
                        self.ScopeAxes_(i).XGrid = 'off' ;
                        self.ScopeAxes_(i).YGrid = 'off' ;
                    else
                        self.ScopeAxes_(i).XGrid = 'on' ;
                        self.ScopeAxes_(i).YGrid = 'on' ;
                    end
                end
            end
        end
        
        function toggleInvertColors_(self) %#ok<MANU>
            % TODO: Implement color inversion for scope plots
        end
        
        function showAbout_(self) %#ok<MANU>
            uialert(self.Figure_, ...
                    sprintf('WaveSurfer %s\nHarnett Lab / MIT\nModernized for MATLAB R2025b', ws.versionString()), ...
                    'About WaveSurfer') ;
        end
        
        function closeRequested_(self)
            % Main window close = quit WaveSurfer
            self.quitRequested_() ;
        end
        
        % =====================================================================
        % Internal data streaming
        % =====================================================================
        function addData_(self, t, scaledAnalogData, rawDigitalData)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            nScans = size(scaledAnalogData, 1) ;
            if nScans == 0
                return
            end
            
            % Build time vector
            fs = model.AcquisitionSampleRate ;
            dt = 1 / fs ;
            tEnd = t ;
            tStart = tEnd - nScans * dt ;
            timeVector = linspace(tStart + dt, tEnd, nScans)' ;
            
            nAI = size(scaledAnalogData, 2) ;
            nDI = size(rawDigitalData, 2) ;
            
            % Add data to animated lines
            plotIndex = 1 ;
            for i = 1:nAI
                if plotIndex <= length(self.ScopeLines_) && ~isempty(self.ScopeLines_{plotIndex}) && isvalid(self.ScopeLines_{plotIndex})
                    addpoints(self.ScopeLines_{plotIndex}, timeVector, scaledAnalogData(:, i)) ;
                end
                plotIndex = plotIndex + 1 ;
            end
            for i = 1:nDI
                if plotIndex <= length(self.ScopeLines_) && ~isempty(self.ScopeLines_{plotIndex}) && isvalid(self.ScopeLines_{plotIndex})
                    addpoints(self.ScopeLines_{plotIndex}, timeVector, double(rawDigitalData(:, i))) ;
                end
                plotIndex = plotIndex + 1 ;
            end
        end
    end
    
end
