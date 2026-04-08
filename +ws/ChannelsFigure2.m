classdef ChannelsFigure2 < ws.AppFigure
    % ChannelsFigure2 — Modern uifigure-based Channels window.
    % Replaces the old ChannelsFigure (MCOSFigureWithSelfControl).
    % Uses a tabbed layout with one tab per channel type (AI, AO, DI, DO).
    
    properties (Access = protected)
        TabGroup_
        
        % AI Tab
        AITab_
        AITable_
        AddAIButton_
        DeleteAIButton_
        
        % AO Tab
        AOTab_
        AOTable_
        AddAOButton_
        DeleteAOButton_
        
        % DI Tab
        DITab_
        DITable_
        AddDIButton_
        DeleteDIButton_
        
        % DO Tab
        DOTab_
        DOTable_
        AddDOButton_
        DeleteDOButton_
    end
    
    methods
        function self = ChannelsFigure2(model)
            self@ws.AppFigure(model, 'Channels', [650 400]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateChannels', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
                model.subscribeMe(self, 'DidChangeNumberOfInputChannels', '', 'update') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'1x'} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            
            self.TabGroup_ = uitabgroup(self.GridLayout_) ;
            
            self.createAITab_() ;
            self.createAOTab_() ;
            self.createDITab_() ;
            self.createDOTab_() ;
        end
        
        function createAITab_(self)
            self.AITab_ = uitab(self.TabGroup_, 'Title', 'Analog Input') ;
            g = uigridlayout(self.AITab_, ...
                'RowHeight', {'1x', 32}, ...
                'ColumnWidth', {'1x', 80, 10, 100}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6) ;
            
            self.AITable_ = uitable(g, ...
                'ColumnName', {'Name', 'Terminal', 'Scale', 'Units', 'Active', 'Delete?'}, ...
                'ColumnFormat', {'char', 'char', 'numeric', 'char', 'logical', 'logical'}, ...
                'ColumnEditable', [true true true true true true], ...
                'CellEditCallback', @(src, evt) self.aiTableEdited_(evt)) ;
            self.AITable_.Layout.Row = 1 ; self.AITable_.Layout.Column = [1 4] ;
            
            self.AddAIButton_ = uibutton(g, 'Text', 'Add', ...
                'ButtonPushedFcn', @(~,~) self.addAIChannelPushed_()) ;
            self.AddAIButton_.Layout.Row = 2 ; self.AddAIButton_.Layout.Column = 2 ;
            
            self.DeleteAIButton_ = uibutton(g, 'Text', 'Delete Marked', ...
                'ButtonPushedFcn', @(~,~) self.deleteAIChannelsPushed_()) ;
            self.DeleteAIButton_.Layout.Row = 2 ; self.DeleteAIButton_.Layout.Column = 4 ;
        end
        
        function createAOTab_(self)
            self.AOTab_ = uitab(self.TabGroup_, 'Title', 'Analog Output') ;
            g = uigridlayout(self.AOTab_, ...
                'RowHeight', {'1x', 32}, ...
                'ColumnWidth', {'1x', 80, 10, 100}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6) ;
            
            self.AOTable_ = uitable(g, ...
                'ColumnName', {'Name', 'Terminal', 'Scale', 'Units', 'Delete?'}, ...
                'ColumnFormat', {'char', 'char', 'numeric', 'char', 'logical'}, ...
                'ColumnEditable', [true true true true true], ...
                'CellEditCallback', @(src, evt) self.aoTableEdited_(evt)) ;
            self.AOTable_.Layout.Row = 1 ; self.AOTable_.Layout.Column = [1 4] ;
            
            self.AddAOButton_ = uibutton(g, 'Text', 'Add', ...
                'ButtonPushedFcn', @(~,~) self.addAOChannelPushed_()) ;
            self.AddAOButton_.Layout.Row = 2 ; self.AddAOButton_.Layout.Column = 2 ;
            
            self.DeleteAOButton_ = uibutton(g, 'Text', 'Delete Marked', ...
                'ButtonPushedFcn', @(~,~) self.deleteAOChannelsPushed_()) ;
            self.DeleteAOButton_.Layout.Row = 2 ; self.DeleteAOButton_.Layout.Column = 4 ;
        end
        
        function createDITab_(self)
            self.DITab_ = uitab(self.TabGroup_, 'Title', 'Digital Input') ;
            g = uigridlayout(self.DITab_, ...
                'RowHeight', {'1x', 32}, ...
                'ColumnWidth', {'1x', 80, 10, 100}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6) ;
            
            self.DITable_ = uitable(g, ...
                'ColumnName', {'Name', 'Terminal ID', 'Active', 'Delete?'}, ...
                'ColumnFormat', {'char', 'numeric', 'logical', 'logical'}, ...
                'ColumnEditable', [true true true true], ...
                'CellEditCallback', @(src, evt) self.diTableEdited_(evt)) ;
            self.DITable_.Layout.Row = 1 ; self.DITable_.Layout.Column = [1 4] ;
            
            self.AddDIButton_ = uibutton(g, 'Text', 'Add', ...
                'ButtonPushedFcn', @(~,~) self.addDIChannelPushed_()) ;
            self.AddDIButton_.Layout.Row = 2 ; self.AddDIButton_.Layout.Column = 2 ;
            
            self.DeleteDIButton_ = uibutton(g, 'Text', 'Delete Marked', ...
                'ButtonPushedFcn', @(~,~) self.deleteDIChannelsPushed_()) ;
            self.DeleteDIButton_.Layout.Row = 2 ; self.DeleteDIButton_.Layout.Column = 4 ;
        end
        
        function createDOTab_(self)
            self.DOTab_ = uitab(self.TabGroup_, 'Title', 'Digital Output') ;
            g = uigridlayout(self.DOTab_, ...
                'RowHeight', {'1x', 32}, ...
                'ColumnWidth', {'1x', 80, 10, 100}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6) ;
            
            self.DOTable_ = uitable(g, ...
                'ColumnName', {'Name', 'Terminal ID', 'Timed?', 'On Demand', 'Delete?'}, ...
                'ColumnFormat', {'char', 'numeric', 'logical', 'logical', 'logical'}, ...
                'ColumnEditable', [true true true true true], ...
                'CellEditCallback', @(src, evt) self.doTableEdited_(evt)) ;
            self.DOTable_.Layout.Row = 1 ; self.DOTable_.Layout.Column = [1 4] ;
            
            self.AddDOButton_ = uibutton(g, 'Text', 'Add', ...
                'ButtonPushedFcn', @(~,~) self.addDOChannelPushed_()) ;
            self.AddDOButton_.Layout.Row = 2 ; self.AddDOButton_.Layout.Column = 2 ;
            
            self.DeleteDOButton_ = uibutton(g, 'Text', 'Delete Marked', ...
                'ButtonPushedFcn', @(~,~) self.deleteDOChannelsPushed_()) ;
            self.DeleteDOButton_.Layout.Row = 2 ; self.DeleteDOButton_.Layout.Column = 4 ;
        end
        
        % =====================================================================
        % Update
        % =====================================================================
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            self.updateAITable_() ;
            self.updateAOTable_() ;
            self.updateDITable_() ;
            self.updateDOTable_() ;
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            isIdle = isequal(model.State, 'idle') ;
            onOff = ws.onIff(isIdle) ;
            
            self.AITable_.Enable = onOff ;
            self.AOTable_.Enable = onOff ;
            self.DITable_.Enable = onOff ;
            self.DOTable_.Enable = onOff ;
            self.AddAIButton_.Enable = onOff ;
            self.DeleteAIButton_.Enable = onOff ;
            self.AddAOButton_.Enable = onOff ;
            self.DeleteAOButton_.Enable = onOff ;
            self.AddDIButton_.Enable = onOff ;
            self.DeleteDIButton_.Enable = onOff ;
            self.AddDOButton_.Enable = onOff ;
            self.DeleteDOButton_.Enable = onOff ;
        end
        
        % --- Table population ---
        function updateAITable_(self)
            model = self.Model_ ;
            names = model.AIChannelNames ;
            terminalIDs = model.AIChannelTerminalIDs ;
            scales = model.AIChannelScales ;
            units = model.AIChannelUnits ;
            isActive = model.IsAIChannelActive ;
            isMarked = model.IsAIChannelMarkedForDeletion ;
            n = length(names) ;
            data = cell(n, 6) ;
            for i = 1:n
                data{i,1} = names{i} ;
                data{i,2} = sprintf('AI%d', terminalIDs(i)) ;
                data{i,3} = scales(i) ;
                data{i,4} = units{i} ;
                data{i,5} = isActive(i) ;
                data{i,6} = isMarked(i) ;
            end
            self.AITable_.Data = data ;
        end
        
        function updateAOTable_(self)
            model = self.Model_ ;
            names = model.AOChannelNames ;
            terminalIDs = model.AOChannelTerminalIDs ;
            scales = model.AOChannelScales ;
            units = model.AOChannelUnits ;
            isMarked = model.IsAOChannelMarkedForDeletion ;
            n = length(names) ;
            data = cell(n, 5) ;
            for i = 1:n
                data{i,1} = names{i} ;
                data{i,2} = sprintf('AO%d', terminalIDs(i)) ;
                data{i,3} = scales(i) ;
                data{i,4} = units{i} ;
                data{i,5} = isMarked(i) ;
            end
            self.AOTable_.Data = data ;
        end
        
        function updateDITable_(self)
            model = self.Model_ ;
            names = model.DIChannelNames ;
            terminalIDs = model.DIChannelTerminalIDs ;
            isActive = model.IsDIChannelActive ;
            isMarked = model.IsDIChannelMarkedForDeletion ;
            n = length(names) ;
            data = cell(n, 4) ;
            for i = 1:n
                data{i,1} = names{i} ;
                data{i,2} = terminalIDs(i) ;
                data{i,3} = isActive(i) ;
                data{i,4} = isMarked(i) ;
            end
            self.DITable_.Data = data ;
        end
        
        function updateDOTable_(self)
            model = self.Model_ ;
            names = model.DOChannelNames ;
            terminalIDs = model.DOChannelTerminalIDs ;
            isTimed = model.IsDOChannelTimed ;
            onDemandState = model.DOChannelStateIfUntimed ;
            isMarked = model.IsDOChannelMarkedForDeletion ;
            n = length(names) ;
            data = cell(n, 5) ;
            for i = 1:n
                data{i,1} = names{i} ;
                data{i,2} = terminalIDs(i) ;
                data{i,3} = isTimed(i) ;
                data{i,4} = onDemandState(i) ;
                data{i,5} = isMarked(i) ;
            end
            self.DOTable_.Data = data ;
        end
        
        % =====================================================================
        % Callbacks
        % =====================================================================
        function aiTableEdited_(self, event)
            idx = event.Indices ;
            row = idx(1) ; col = idx(2) ;
            try
                switch col
                    case 1  % Name
                        self.Model_.do('setSingleAIChannelName', row, event.NewData) ;
                    case 2  % Terminal
                        termID = sscanf(event.NewData, 'AI%d') ;
                        if ~isempty(termID)
                            self.Model_.do('setSingleAIChannelTerminalID', row, termID) ;
                        end
                    case 3  % Scale
                        self.Model_.do('setSingleAIChannelScale', row, event.NewData) ;
                    case 4  % Units
                        self.Model_.do('setSingleAIChannelUnits', row, event.NewData) ;
                    case 5  % Active
                        isActive = self.Model_.IsAIChannelActive ;
                        isActive(row) = event.NewData ;
                        self.Model_.do('set', 'IsAIChannelActive', isActive) ;
                    case 6  % Delete mark
                        self.Model_.do('setSingleAIChannelMarkedForDeletion', row, event.NewData) ;
                end
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function aoTableEdited_(self, event)
            idx = event.Indices ;
            row = idx(1) ; col = idx(2) ;
            try
                switch col
                    case 1
                        self.Model_.do('setSingleAOChannelName', row, event.NewData) ;
                    case 2
                        termID = sscanf(event.NewData, 'AO%d') ;
                        if ~isempty(termID)
                            self.Model_.do('setSingleAOChannelTerminalID', row, termID) ;
                        end
                    case 3
                        self.Model_.do('setSingleAOChannelScale', row, event.NewData) ;
                    case 4
                        self.Model_.do('setSingleAOChannelUnits', row, event.NewData) ;
                    case 5
                        self.Model_.do('setSingleAOChannelMarkedForDeletion', row, event.NewData) ;
                end
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function diTableEdited_(self, event)
            idx = event.Indices ;
            row = idx(1) ; col = idx(2) ;
            try
                switch col
                    case 1
                        self.Model_.do('setSingleDIChannelName', row, event.NewData) ;
                    case 2
                        self.Model_.do('setSingleDIChannelTerminalID', row, event.NewData) ;
                    case 3
                        isActive = self.Model_.IsDIChannelActive ;
                        isActive(row) = event.NewData ;
                        self.Model_.do('set', 'IsDIChannelActive', isActive) ;
                    case 4
                        self.Model_.do('setSingleDIChannelMarkedForDeletion', row, event.NewData) ;
                end
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function doTableEdited_(self, event)
            idx = event.Indices ;
            row = idx(1) ; col = idx(2) ;
            try
                switch col
                    case 1
                        self.Model_.do('setSingleDOChannelName', row, event.NewData) ;
                    case 2
                        self.Model_.do('setSingleDOChannelTerminalID', row, event.NewData) ;
                    case 3
                        isTimed = self.Model_.IsDOChannelTimed ;
                        isTimed(row) = event.NewData ;
                        self.Model_.do('set', 'IsDOChannelTimed', isTimed) ;
                    case 4
                        onDemand = self.Model_.DOChannelStateIfUntimed ;
                        onDemand(row) = event.NewData ;
                        self.Model_.do('set', 'DOChannelStateIfUntimed', onDemand) ;
                    case 5
                        self.Model_.do('setSingleDOChannelMarkedForDeletion', row, event.NewData) ;
                end
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function addAIChannelPushed_(self)
            try self.Model_.do('addAIChannel') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function deleteAIChannelsPushed_(self)
            try self.Model_.do('deleteMarkedAIChannels') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function addAOChannelPushed_(self)
            try self.Model_.do('addAOChannel') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function deleteAOChannelsPushed_(self)
            try self.Model_.do('deleteMarkedAOChannels') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function addDIChannelPushed_(self)
            try self.Model_.do('addDIChannel') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function deleteDIChannelsPushed_(self)
            try self.Model_.do('deleteMarkedDIChannels') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function addDOChannelPushed_(self)
            try self.Model_.do('addDOChannel') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function deleteDOChannelsPushed_(self)
            try self.Model_.do('deleteMarkedDOChannels') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function closeRequested_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) || model.isIdleSensuLato()
                self.hide() ;
            end
        end
    end
    
end
