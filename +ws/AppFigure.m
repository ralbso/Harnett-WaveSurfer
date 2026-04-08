classdef (Abstract) AppFigure < ws.EventSubscriber
    % AppFigure — Modern base class for all WaveSurfer windows.
    %
    % Replaces the old MCOSFigure + MCOSFigureWithSelfControl + Controller
    % hierarchy with a single unified class that:
    %   - Uses uifigure instead of figure() for modern look & feel
    %   - Uses uigridlayout for resolution-independent layouts
    %   - Owns all callback logic directly (no separate Controller)
    %   - Supports deferred updates (disable/enable pattern preserved)
    %   - Works cross-platform with proper DPI scaling
    %
    % Subclasses must implement:
    %   createComponents_(self)  — build all UI components
    %   updateControlPropertiesImplementation_(self)  — sync controls with model
    %   updateControlEnablementImplementation_(self)  — sync Enable states
    %
    % Subclasses may optionally override:
    %   updateImplementation_(self)  — full refresh (default calls the above)
    %   closeRequested_(self)  — custom close behavior
    
    properties (Access = protected)
        Figure_           % uifigure handle
        Model_            % reference to the data model
        GridLayout_       % root uigridlayout for the figure
    end
    
    properties (Access = protected, Transient = true)
        DegreeOfEnablement_ = 1
        NCallsToUpdateWhileDisabled_ = []
        NCallsToUpdateControlPropertiesWhileDisabled_ = []
        NCallsToUpdateControlEnablementWhileDisabled_ = []
    end
    
    properties (Dependent = true, Transient = true)
        AreUpdatesEnabled
    end
    
    methods
        function self = AppFigure(model, titleString, figureSize)
            % AppFigure(model)
            % AppFigure(model, titleString)
            % AppFigure(model, titleString, [width height])
            
            if ~exist('titleString', 'var') || isempty(titleString)
                titleString = 'WaveSurfer' ;
            end
            if ~exist('figureSize', 'var') || isempty(figureSize)
                figureSize = [800 600] ;
            end
            
            % Create the modern figure
            self.Figure_ = uifigure('Name', titleString, ...
                                    'Position', [100 100 figureSize], ...
                                    'Visible', 'off', ...
                                    'HandleVisibility', 'off', ...
                                    'CloseRequestFcn', @(~,~) self.closeRequested_(), ...
                                    'AutoResizeChildren', 'off') ;
            
            % Create a root grid layout for the figure
            self.GridLayout_ = uigridlayout(self.Figure_, ...
                                            'Padding', [0 0 0 0], ...
                                            'RowSpacing', 0, ...
                                            'ColumnSpacing', 0) ;
            
            % Store model reference and subscribe
            if exist('model', 'var') && ~isempty(model)
                self.Model_ = model ;
                if isvalid(model)
                    model.subscribeMe(self, 'UpdateReadiness', '', 'updateReadiness') ;
                end
            else
                self.Model_ = [] ;
            end
            
            % Let the subclass create its components
            self.createComponents_() ;
        end
        
        function delete(self)
            self.unsubscribeFromAll() ;
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                delete(self.Figure_) ;
            end
            self.Figure_ = [] ;
            self.Model_ = [] ;
        end
        
        % --- Visibility ---
        function show(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                self.Figure_.Visible = 'on' ;
            end
        end
        
        function hide(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                self.Figure_.Visible = 'off' ;
            end
        end
        
        function raise(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                figure(self.Figure_) ;  % bring to front
            end
        end
        
        % --- Update API (preserves deferred-update pattern) ---
        function update(self, varargin)
            if self.AreUpdatesEnabled
                self.updateImplementation_() ;
            else
                self.NCallsToUpdateWhileDisabled_ = self.NCallsToUpdateWhileDisabled_ + 1 ;
            end
        end
        
        function updateControlProperties(self, varargin)
            if self.AreUpdatesEnabled
                self.updateControlPropertiesImplementation_() ;
            else
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = self.NCallsToUpdateControlPropertiesWhileDisabled_ + 1 ;
            end
        end
        
        function updateControlEnablement(self, varargin)
            if self.AreUpdatesEnabled
                self.updateControlEnablementImplementation_() ;
            else
                self.NCallsToUpdateControlEnablementWhileDisabled_ = self.NCallsToUpdateControlEnablementWhileDisabled_ + 1 ;
            end
        end
        
        function updateReadiness(self, varargin)
            if isempty(self.Model_) || ~isvalid(self.Model_)
                pointerShape = 'arrow' ;
            elseif self.Model_.IsReady
                pointerShape = 'arrow' ;
            else
                pointerShape = 'watch' ;
            end
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                self.Figure_.Pointer = pointerShape ;
            end
        end
        
        % --- Enable/disable deferred updates ---
        function set.AreUpdatesEnabled(self, newValue)
            if ~(islogical(newValue) && isscalar(newValue))
                return
            end
            
            wasBefore = self.AreUpdatesEnabled ;
            newSign = 2*double(newValue) - 1 ;
            raw = self.DegreeOfEnablement_ + newSign ;
            self.DegreeOfEnablement_ = min(raw, 1) ;
            isAfter = self.AreUpdatesEnabled ;
            
            if isAfter && ~wasBefore
                % Re-enabled — flush deferred updates
                if self.NCallsToUpdateWhileDisabled_ > 0
                    self.updateImplementation_() ;
                elseif self.NCallsToUpdateControlPropertiesWhileDisabled_ > 0
                    self.updateControlPropertiesImplementation_() ;
                elseif self.NCallsToUpdateControlEnablementWhileDisabled_ > 0
                    self.updateControlEnablementImplementation_() ;
                end
                self.NCallsToUpdateWhileDisabled_ = [] ;
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = [] ;
                self.NCallsToUpdateControlEnablementWhileDisabled_ = [] ;
            elseif ~isAfter && wasBefore
                % Just disabled
                self.NCallsToUpdateWhileDisabled_ = 0 ;
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = 0 ;
                self.NCallsToUpdateControlEnablementWhileDisabled_ = 0 ;
            end
        end
        
        function value = get.AreUpdatesEnabled(self)
            value = (self.DegreeOfEnablement_ > 0) ;
        end
        
        % --- Position management ---
        function constrainPositionToMonitors(self, monitorPositions)
            if isempty(self.Figure_) || ~isvalid(self.Figure_)
                return
            end
            pos = self.Figure_.Position ;
            figOffset = pos(1:2) ;
            figSize = pos(3:4) ;
            
            nMonitors = size(monitorPositions, 1) ;
            bestTranslation = [0 0] ;
            bestDist = Inf ;
            for i = 1:nMonitors
                monPos = monitorPositions(i, :) ;
                monOffset = monPos(1:2) ;
                monSize = monPos(3:4) ;
                tx = clampTranslation(figOffset(1), figSize(1), monOffset(1), monSize(1)) ;
                ty = clampTranslation(figOffset(2), figSize(2), monOffset(2), monSize(2)) ;
                d = hypot(tx, ty) ;
                if d < bestDist
                    bestDist = d ;
                    bestTranslation = [tx ty] ;
                end
            end
            self.Figure_.Position = [figOffset + bestTranslation, figSize] ;
            
            function t = clampTranslation(offset, sz, screenOffset, screenSize)
                top = offset + sz ;
                screenTop = screenOffset + screenSize ;
                if offset < screenOffset
                    t = screenOffset - offset ;
                elseif top > screenTop
                    t = (screenTop - sz) - offset ;
                else
                    t = 0 ;
                end
            end
        end
        
        % --- Window layout encode/decode (for protocol persistence) ---
        function layout = encodeWindowLayout(self)
            if isempty(self.Figure_) || ~isvalid(self.Figure_)
                layout = struct('Position', [100 100 800 600], 'IsVisible', false) ;
            else
                pos = self.Figure_.Position ;
                vis = strcmp(self.Figure_.Visible, 'on') ;
                layout = struct('Position', pos, 'IsVisible', vis) ;
            end
        end
        
        function decodeWindowLayout(self, layoutStruct, monitorPositions)
            if isfield(layoutStruct, 'Position')
                self.Figure_.Position = layoutStruct.Position ;
                self.constrainPositionToMonitors(monitorPositions) ;
            end
            visField = 'IsVisible' ;
            if ~isfield(layoutStruct, visField)
                visField = 'Visible' ;
            end
            if isfield(layoutStruct, visField)
                if layoutStruct.(visField)
                    self.Figure_.Visible = 'on' ;
                else
                    self.Figure_.Visible = 'off' ;
                end
            end
        end
    end
    
    % --- Abstract methods for subclasses ---
    methods (Abstract, Access = protected)
        createComponents_(self)
        updateControlPropertiesImplementation_(self)
        updateControlEnablementImplementation_(self)
    end
    
    methods (Access = protected)
        function updateImplementation_(self)
            % Default: full refresh = properties + enablement
            self.updateControlPropertiesImplementation_() ;
            self.updateControlEnablementImplementation_() ;
        end
        
        function closeRequested_(self)
            % Default: just hide the window (main window overrides to quit)
            self.hide() ;
        end
    end
    
end
