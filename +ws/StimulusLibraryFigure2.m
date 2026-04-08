classdef StimulusLibraryFigure2 < ws.AppFigure
    % StimulusLibraryFigure2 — Modern uifigure-based Stimulus Library window.
    % Replaces StimulusLibraryFigure + StimulusLibraryController.
    %
    % Layout: Left panel has three listboxes (Sequences, Maps, Stimuli).
    % Right panel shows detail editor for the selected item type.
    
    properties (Access = protected)
        % Left panel: listboxes
        SequencesListbox_
        MapsListbox_
        StimuliListbox_
        
        % Right panel: detail tabs
        DetailPanel_
        
        % Sequence detail
        SequencePanel_
        SequenceNameField_
        SequenceTable_
        
        % Map detail
        MapPanel_
        MapNameField_
        MapDurationField_
        MapTable_
        
        % Stimulus detail
        StimulusPanel_
        StimulusNameField_
        StimulusFunctionDropdown_
        StimulusParamLabels_
        StimulusParamFields_
        
        % Edit menu
        EditMenu_
    end
    
    methods
        function self = StimulusLibraryFigure2(model)
            self@ws.AppFigure(model, 'Stimulus Library', [750 500]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateStimulusLibrary', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            % Root: left listbox panel | right detail panel
            self.GridLayout_.RowHeight = {'1x'} ;
            self.GridLayout_.ColumnWidth = {180, '1x'} ;
            self.GridLayout_.Padding = [0 0 0 0] ;
            self.GridLayout_.ColumnSpacing = 0 ;
            
            self.createLeftPanel_() ;
            self.createRightPanel_() ;
            self.createEditMenu_() ;
        end
        
        function createLeftPanel_(self)
            leftGrid = uigridlayout(self.GridLayout_, ...
                'RowHeight', {16, '1x', 16, '1x', 16, '1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [6 6 6 6], 'RowSpacing', 2) ;
            leftGrid.Layout.Row = 1 ;
            leftGrid.Layout.Column = 1 ;
            
            uilabel(leftGrid, 'Text', 'Sequences', 'FontWeight', 'bold', 'FontSize', 11) ;
            self.SequencesListbox_ = uilistbox(leftGrid, ...
                'Items', {'(None)'}, ...
                'ValueChangedFcn', @(~,~) self.sequenceSelected_()) ;
            
            uilabel(leftGrid, 'Text', 'Maps', 'FontWeight', 'bold', 'FontSize', 11).Layout.Row = 3 ;
            self.MapsListbox_ = uilistbox(leftGrid, ...
                'Items', {'(None)'}, ...
                'ValueChangedFcn', @(~,~) self.mapSelected_()) ;
            self.MapsListbox_.Layout.Row = 4 ;
            
            uilabel(leftGrid, 'Text', 'Stimuli', 'FontWeight', 'bold', 'FontSize', 11).Layout.Row = 5 ;
            self.StimuliListbox_ = uilistbox(leftGrid, ...
                'Items', {'(None)'}, ...
                'ValueChangedFcn', @(~,~) self.stimulusSelected_()) ;
            self.StimuliListbox_.Layout.Row = 6 ;
        end
        
        function createRightPanel_(self)
            self.DetailPanel_ = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [6 6 6 6]) ;
            self.DetailPanel_.Layout.Row = 1 ;
            self.DetailPanel_.Layout.Column = 2 ;
            
            % Sequence panel
            self.SequencePanel_ = uipanel(self.DetailPanel_, 'Title', 'Sequence') ;
            sg = uigridlayout(self.SequencePanel_, ...
                'RowHeight', {28, '1x'}, ...
                'ColumnWidth', {60, '1x'}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 6) ;
            uilabel(sg, 'Text', 'Name:') ;
            self.SequenceNameField_ = uieditfield(sg, ...
                'ValueChangedFcn', @(~,~) self.sequenceNameChanged_()) ;
            self.SequenceNameField_.Layout.Column = 2 ;
            self.SequenceTable_ = uitable(sg, ...
                'ColumnName', {'Map'}, ...
                'ColumnFormat', {'char'}, ...
                'ColumnEditable', true, ...
                'CellEditCallback', @(~,evt) self.sequenceTableEdited_(evt)) ;
            self.SequenceTable_.Layout.Row = 2 ;
            self.SequenceTable_.Layout.Column = [1 2] ;
            
            % Map panel
            self.MapPanel_ = uipanel(self.DetailPanel_, 'Title', 'Map') ;
            mg = uigridlayout(self.MapPanel_, ...
                'RowHeight', {28, 28, '1x'}, ...
                'ColumnWidth', {70, '1x', 40}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 6) ;
            uilabel(mg, 'Text', 'Name:') ;
            self.MapNameField_ = uieditfield(mg, ...
                'ValueChangedFcn', @(~,~) self.mapNameChanged_()) ;
            self.MapNameField_.Layout.Column = [2 3] ;
            uilabel(mg, 'Text', 'Duration:').Layout.Row = 2 ;
            self.MapDurationField_ = uieditfield(mg, ...
                'ValueChangedFcn', @(~,~) self.mapDurationChanged_()) ;
            self.MapDurationField_.Layout.Row = 2 ; self.MapDurationField_.Layout.Column = 2 ;
            uilabel(mg, 'Text', 's').Layout.Row = 2 ;
            self.MapTable_ = uitable(mg, ...
                'ColumnName', {'Channel', 'Stimulus'}, ...
                'ColumnFormat', {'char', 'char'}, ...
                'ColumnEditable', [false true], ...
                'CellEditCallback', @(~,evt) self.mapTableEdited_(evt)) ;
            self.MapTable_.Layout.Row = 3 ;
            self.MapTable_.Layout.Column = [1 3] ;
            
            % Stimulus panel
            self.StimulusPanel_ = uipanel(self.DetailPanel_, 'Title', 'Stimulus') ;
            stimGrid = uigridlayout(self.StimulusPanel_, ...
                'RowHeight', repmat({28}, 1, 10), ...
                'ColumnWidth', {100, '1x'}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            uilabel(stimGrid, 'Text', 'Name:') ;
            self.StimulusNameField_ = uieditfield(stimGrid, ...
                'ValueChangedFcn', @(~,~) self.stimulusNameChanged_()) ;
            self.StimulusNameField_.Layout.Column = 2 ;
            uilabel(stimGrid, 'Text', 'Function:').Layout.Row = 2 ;
            self.StimulusFunctionDropdown_ = uidropdown(stimGrid, ...
                'Items', ws.Stimulus.AllowedTypeDisplayStrings, ...
                'ValueChangedFcn', @(~,~) self.stimulusFunctionChanged_()) ;
            self.StimulusFunctionDropdown_.Layout.Row = 2 ;
            self.StimulusFunctionDropdown_.Layout.Column = 2 ;
            
            % Dynamic parameter fields (up to 8)
            nMaxParams = 8 ;
            self.StimulusParamLabels_ = gobjects(1, nMaxParams) ;
            self.StimulusParamFields_ = gobjects(1, nMaxParams) ;
            for i = 1:nMaxParams
                self.StimulusParamLabels_(i) = uilabel(stimGrid, 'Text', '', 'Visible', 'off') ;
                self.StimulusParamLabels_(i).Layout.Row = 2 + i ;
                self.StimulusParamLabels_(i).Layout.Column = 1 ;
                self.StimulusParamFields_(i) = uieditfield(stimGrid, 'Visible', 'off', ...
                    'ValueChangedFcn', @(~,~) self.stimulusParamChanged_(i)) ;
                self.StimulusParamFields_(i).Layout.Row = 2 + i ;
                self.StimulusParamFields_(i).Layout.Column = 2 ;
            end
            
            % Start with all panels hidden
            self.SequencePanel_.Visible = 'off' ;
            self.MapPanel_.Visible = 'off' ;
            self.StimulusPanel_.Visible = 'off' ;
        end
        
        function createEditMenu_(self)
            self.EditMenu_ = uimenu(self.Figure_, 'Text', 'Edit') ;
            
            uimenu(self.EditMenu_, 'Text', 'Add Sequence', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('addNewStimulusSequence')) ;
            uimenu(self.EditMenu_, 'Text', 'Duplicate Sequence', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('duplicateSelectedStimulusLibraryItem')) ;
            uimenu(self.EditMenu_, 'Text', 'Add Map to Sequence', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('addMapToSelectedStimulusLibraryItem')) ;
            uimenu(self.EditMenu_, 'Text', 'Delete Maps from Sequence', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('deleteMarkedMapsFromSelectedSequence')) ;
            
            uimenu(self.EditMenu_, 'Text', 'Add Map', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('addNewStimulusMap')) ;
            uimenu(self.EditMenu_, 'Text', 'Duplicate Map', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('duplicateSelectedStimulusLibraryItem')) ;
            uimenu(self.EditMenu_, 'Text', 'Add Channel to Map', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('addChannelToSelectedStimulusLibraryItem')) ;
            uimenu(self.EditMenu_, 'Text', 'Delete Channels from Map', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('deleteMarkedChannelsFromSelectedStimulusMap')) ;
            
            uimenu(self.EditMenu_, 'Text', 'Add Stimulus', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('addNewStimulus')) ;
            uimenu(self.EditMenu_, 'Text', 'Duplicate Stimulus', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('duplicateSelectedStimulusLibraryItem')) ;
            
            uimenu(self.EditMenu_, 'Text', 'Delete Selected Item', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) self.doModel_('deleteSelectedStimulusLibraryItem')) ;
            
            uimenu(self.EditMenu_, 'Text', 'Clear Library', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) self.clearLibrary_()) ;
        end
        
        % =================================================================
        % Updates
        % =================================================================
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            
            selectedClassName = model.selectedStimulusLibraryItemClassName() ;
            isSeq = isequal(selectedClassName, 'ws.StimulusSequence') ;
            isMap = isequal(selectedClassName, 'ws.StimulusMap') ;
            isStim = isequal(selectedClassName, 'ws.Stimulus') ;
            
            % Populate listboxes
            self.populateListbox_(self.SequencesListbox_, model, 'ws.StimulusSequence') ;
            self.populateListbox_(self.MapsListbox_, model, 'ws.StimulusMap') ;
            self.populateListbox_(self.StimuliListbox_, model, 'ws.Stimulus') ;
            
            % Show the appropriate detail panel
            self.SequencePanel_.Visible = ws.onIff(isSeq) ;
            self.MapPanel_.Visible = ws.onIff(isMap) ;
            self.StimulusPanel_.Visible = ws.onIff(isStim) ;
            
            if isSeq, self.updateSequencePanel_(model) ; end
            if isMap, self.updateMapPanel_(model) ; end
            if isStim, self.updateStimulusPanel_(model) ; end
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            isIdle = isequal(model.State, 'idle') ;
            onOff = ws.onIff(isIdle) ;
            self.SequencesListbox_.Enable = onOff ;
            self.MapsListbox_.Enable = onOff ;
            self.StimuliListbox_.Enable = onOff ;
        end
        
        % =================================================================
        % Internal helpers
        % =================================================================
        function populateListbox_(~, lb, model, className)
            names = model.propertyFromEachStimulusLibraryItemInClass(className, 'Name') ;
            selIdx = model.indexOfStimulusLibraryClassSelection(className) ;
            if isempty(names)
                lb.Items = {'(None)'} ;
                lb.Value = '(None)' ;
            else
                lb.Items = names ;
                if ~isempty(selIdx) && selIdx >= 1 && selIdx <= length(names)
                    lb.Value = names{selIdx} ;
                end
            end
        end
        
        function updateSequencePanel_(self, model)
            idx = model.indexOfStimulusLibraryClassSelection('ws.StimulusSequence') ;
            if isempty(idx), return ; end
            self.SequenceNameField_.Value = model.stimulusLibraryItemProperty('ws.StimulusSequence', idx, 'Name') ;
            
            % Get maps in this sequence
            try
                mapNames = model.stimulusLibrarySelectedSequenceMapNames() ;
                nMaps = length(mapNames) ;
                data = cell(nMaps, 1) ;
                for i = 1:nMaps
                    data{i,1} = mapNames{i} ;
                end
                self.SequenceTable_.Data = data ;
            catch
                self.SequenceTable_.Data = {} ;
            end
        end
        
        function updateMapPanel_(self, model)
            idx = model.indexOfStimulusLibraryClassSelection('ws.StimulusMap') ;
            if isempty(idx), return ; end
            self.MapNameField_.Value = model.stimulusLibraryItemProperty('ws.StimulusMap', idx, 'Name') ;
            dur = model.stimulusLibraryItemProperty('ws.StimulusMap', idx, 'Duration') ;
            if isnumeric(dur)
                self.MapDurationField_.Value = sprintf('%g', dur) ;
            else
                self.MapDurationField_.Value = dur ;
            end
            
            % Get bindings (channel → stimulus) in this map
            try
                bindingData = model.stimulusLibrarySelectedMapBindingsData() ;
                self.MapTable_.Data = bindingData ;
            catch
                self.MapTable_.Data = {} ;
            end
        end
        
        function updateStimulusPanel_(self, model)
            idx = model.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;
            if isempty(idx), return ; end
            
            self.StimulusNameField_.Value = model.stimulusLibraryItemProperty('ws.Stimulus', idx, 'Name') ;
            
            % Function type
            typeStr = model.stimulusLibraryItemProperty('ws.Stimulus', idx, 'TypeString') ;
            allTypes = ws.Stimulus.AllowedTypeStrings ;
            allDisplayTypes = ws.Stimulus.AllowedTypeDisplayStrings ;
            typeIdx = find(strcmp(typeStr, allTypes), 1) ;
            if ~isempty(typeIdx)
                self.StimulusFunctionDropdown_.Value = allDisplayTypes{typeIdx} ;
            end
            
            % Dynamic parameters
            paramNames = model.stimulusLibraryItemProperty('ws.Stimulus', idx, 'AdditionalParameterNames') ;
            paramDisplayNames = model.stimulusLibraryItemProperty('ws.Stimulus', idx, 'AdditionalParameterDisplayNames') ;
            nParams = length(paramNames) ;
            for i = 1:length(self.StimulusParamLabels_)
                if i <= nParams
                    self.StimulusParamLabels_(i).Text = [paramDisplayNames{i} ':'] ;
                    self.StimulusParamLabels_(i).Visible = 'on' ;
                    val = model.stimulusLibraryItemProperty('ws.Stimulus', idx, paramNames{i}) ;
                    if isnumeric(val)
                        self.StimulusParamFields_(i).Value = sprintf('%g', val) ;
                    else
                        self.StimulusParamFields_(i).Value = val ;
                    end
                    self.StimulusParamFields_(i).Visible = 'on' ;
                else
                    self.StimulusParamLabels_(i).Visible = 'off' ;
                    self.StimulusParamFields_(i).Visible = 'off' ;
                end
            end
        end
        
        % =================================================================
        % Callbacks
        % =================================================================
        function sequenceSelected_(self)
            val = self.SequencesListbox_.Value ;
            names = model_prop_(self, 'ws.StimulusSequence', 'Name') ;
            idx = find(strcmp(val, names), 1) ;
            if ~isempty(idx)
                try self.Model_.do('selectStimulusLibraryItem', 'ws.StimulusSequence', idx) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function mapSelected_(self)
            val = self.MapsListbox_.Value ;
            names = model_prop_(self, 'ws.StimulusMap', 'Name') ;
            idx = find(strcmp(val, names), 1) ;
            if ~isempty(idx)
                try self.Model_.do('selectStimulusLibraryItem', 'ws.StimulusMap', idx) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function stimulusSelected_(self)
            val = self.StimuliListbox_.Value ;
            names = model_prop_(self, 'ws.Stimulus', 'Name') ;
            idx = find(strcmp(val, names), 1) ;
            if ~isempty(idx)
                try self.Model_.do('selectStimulusLibraryItem', 'ws.Stimulus', idx) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function sequenceNameChanged_(self)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.StimulusSequence') ;
            if ~isempty(idx)
                try self.Model_.do('setStimulusLibraryItemProperty', 'ws.StimulusSequence', idx, 'Name', self.SequenceNameField_.Value) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function mapNameChanged_(self)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.StimulusMap') ;
            if ~isempty(idx)
                try self.Model_.do('setStimulusLibraryItemProperty', 'ws.StimulusMap', idx, 'Name', self.MapNameField_.Value) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function mapDurationChanged_(self)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.StimulusMap') ;
            if ~isempty(idx)
                try self.Model_.do('setStimulusLibraryItemProperty', 'ws.StimulusMap', idx, 'Duration', self.MapDurationField_.Value) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function stimulusNameChanged_(self)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;
            if ~isempty(idx)
                try self.Model_.do('setStimulusLibraryItemProperty', 'ws.Stimulus', idx, 'Name', self.StimulusNameField_.Value) ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function stimulusFunctionChanged_(self)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;
            if ~isempty(idx)
                displayStr = self.StimulusFunctionDropdown_.Value ;
                allDisplay = ws.Stimulus.AllowedTypeDisplayStrings ;
                allTypes = ws.Stimulus.AllowedTypeStrings ;
                typeIdx = find(strcmp(displayStr, allDisplay), 1) ;
                if ~isempty(typeIdx)
                    try self.Model_.do('setStimulusLibraryItemProperty', 'ws.Stimulus', idx, 'TypeString', allTypes{typeIdx}) ;
                    catch me, ws.raiseDialogOnException(me) ; end
                end
            end
        end
        
        function stimulusParamChanged_(self, paramIndex)
            idx = self.Model_.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;
            if ~isempty(idx)
                paramNames = self.Model_.stimulusLibraryItemProperty('ws.Stimulus', idx, 'AdditionalParameterNames') ;
                if paramIndex <= length(paramNames)
                    newVal = self.StimulusParamFields_(paramIndex).Value ;
                    try self.Model_.do('setStimulusLibraryItemProperty', 'ws.Stimulus', idx, paramNames{paramIndex}, newVal) ;
                    catch me, ws.raiseDialogOnException(me) ; end
                end
            end
        end
        
        function sequenceTableEdited_(self, event) %#ok<INUSD>
            self.update() ;
        end
        
        function mapTableEdited_(self, event) %#ok<INUSD>
            self.update() ;
        end
        
        function doModel_(self, methodName)
            try self.Model_.do(methodName) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function clearLibrary_(self)
            answer = uiconfirm(self.Figure_, ...
                'Are you sure you want to clear the entire stimulus library?', ...
                'Clear Library', ...
                'Options', {'Clear', 'Cancel'}, ...
                'DefaultOption', 'Cancel') ;
            if strcmp(answer, 'Clear')
                try self.Model_.do('clearStimulusLibrary') ;
                catch me, ws.raiseDialogOnException(me) ; end
            end
        end
        
        function names = model_prop_(self, className, propName)
            names = self.Model_.propertyFromEachStimulusLibraryItemInClass(className, propName) ;
        end
        
        function closeRequested_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) || model.isIdleSensuLato()
                self.hide() ;
            end
        end
    end
    
end
