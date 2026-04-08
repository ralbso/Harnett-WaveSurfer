classdef PlotArrangementDialogFigure2 < handle
    % PlotArrangementDialogFigure2 — Modern modal dialog for scope plot arrangement.
    % Replaces PlotArrangementDialogFigure (MCOSFigureWithSelfControl).
    % Uses a uitable for channel display/size/order instead of dynamic row controls.
    
    properties (Access = protected)
        Figure_
        Table_
        MoveUpButton_
        MoveDownButton_
        OKButton_
        CancelButton_
        
        ChannelNames_
        IsDisplayed_
        PlotHeights_
        RowIndexFromChannelIndex_
        ChannelIndexFromRowIndex_
        CallbackFunction_
    end
    
    methods
        function self = PlotArrangementDialogFigure2(parentFigure, channelNames, isDisplayed, plotHeights, ...
                                                      rowIndexFromChannelIndex, callbackFunction)
            self.ChannelNames_ = channelNames ;
            self.IsDisplayed_ = isDisplayed ;
            self.PlotHeights_ = plotHeights ;
            self.RowIndexFromChannelIndex_ = rowIndexFromChannelIndex ;
            self.ChannelIndexFromRowIndex_ = ws.invertPermutation(rowIndexFromChannelIndex) ;
            self.CallbackFunction_ = callbackFunction ;
            
            nChannels = length(channelNames) ;
            figHeight = max(200, 80 + nChannels * 24 + 50) ;
            
            self.Figure_ = uifigure('Name', 'Plot Arrangement...', ...
                'Position', [200 200 350 figHeight], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal', ...
                'CloseRequestFcn', @(~,~) self.cancel_()) ;
            
            % Center on parent
            if ~isempty(parentFigure) && isvalid(parentFigure)
                parentPos = parentFigure.Position ;
                figSize = self.Figure_.Position(3:4) ;
                newOffset = parentPos(1:2) + (parentPos(3:4) - figSize) / 2 ;
                self.Figure_.Position = [newOffset figSize] ;
            end
            
            g = uigridlayout(self.Figure_, ...
                'RowHeight', {'1x', 32}, ...
                'ColumnWidth', {'1x', 30, 30, '1x', 60, 6, 60}, ...
                'Padding', [10 10 10 10], 'RowSpacing', 8) ;
            
            % Table
            self.Table_ = uitable(g, ...
                'ColumnName', {'Channel', 'Display?', 'Size'}, ...
                'ColumnFormat', {'char', 'logical', 'numeric'}, ...
                'ColumnEditable', [false true true], ...
                'CellEditCallback', @(~, evt) self.tableEdited_(evt)) ;
            self.Table_.Layout.Row = 1 ; self.Table_.Layout.Column = [1 7] ;
            
            % Move buttons
            self.MoveUpButton_ = uibutton(g, 'Text', char(9650), ...
                'ButtonPushedFcn', @(~,~) self.moveUpPushed_()) ;
            self.MoveUpButton_.Layout.Row = 2 ; self.MoveUpButton_.Layout.Column = 2 ;
            
            self.MoveDownButton_ = uibutton(g, 'Text', char(9660), ...
                'ButtonPushedFcn', @(~,~) self.moveDownPushed_()) ;
            self.MoveDownButton_.Layout.Row = 2 ; self.MoveDownButton_.Layout.Column = 3 ;
            
            % OK / Cancel
            self.OKButton_ = uibutton(g, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~,~) self.ok_()) ;
            self.OKButton_.Layout.Row = 2 ; self.OKButton_.Layout.Column = 5 ;
            
            self.CancelButton_ = uibutton(g, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~,~) self.cancel_()) ;
            self.CancelButton_.Layout.Row = 2 ; self.CancelButton_.Layout.Column = 7 ;
            
            self.refreshTable_() ;
        end
        
        function delete(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                delete(self.Figure_) ;
            end
        end
    end
    
    methods (Access = protected)
        function refreshTable_(self)
            nRows = length(self.ChannelIndexFromRowIndex_) ;
            data = cell(nRows, 3) ;
            for iRow = 1:nRows
                iCh = self.ChannelIndexFromRowIndex_(iRow) ;
                data{iRow, 1} = self.ChannelNames_{iCh} ;
                data{iRow, 2} = self.IsDisplayed_(iCh) ;
                data{iRow, 3} = self.PlotHeights_(iCh) ;
            end
            self.Table_.Data = data ;
        end
        
        function tableEdited_(self, event)
            idx = event.Indices ;
            iRow = idx(1) ; col = idx(2) ;
            iCh = self.ChannelIndexFromRowIndex_(iRow) ;
            if col == 2
                self.IsDisplayed_(iCh) = event.NewData ;
            elseif col == 3
                val = event.NewData ;
                if isfinite(val) && isreal(val) && val >= 0.09
                    self.PlotHeights_(iCh) = round(10*val)/10 ;
                end
            end
            self.refreshTable_() ;
        end
        
        function moveUpPushed_(self)
            % Move the first selected row up (swap with row above)
            sel = self.Table_.Selection ;
            if isempty(sel), return ; end
            iRow = sel(1) ;
            if iRow <= 1, return ; end
            self.swapRows_(iRow, iRow-1) ;
            self.refreshTable_() ;
        end
        
        function moveDownPushed_(self)
            sel = self.Table_.Selection ;
            if isempty(sel), return ; end
            iRow = sel(1) ;
            if iRow >= length(self.ChannelIndexFromRowIndex_), return ; end
            self.swapRows_(iRow, iRow+1) ;
            self.refreshTable_() ;
        end
        
        function swapRows_(self, r1, r2)
            newCIFRI = self.ChannelIndexFromRowIndex_ ;
            temp = newCIFRI(r1) ;
            newCIFRI(r1) = newCIFRI(r2) ;
            newCIFRI(r2) = temp ;
            self.ChannelIndexFromRowIndex_ = newCIFRI ;
            self.RowIndexFromChannelIndex_ = ws.invertPermutation(newCIFRI) ;
        end
        
        function ok_(self)
            feval(self.CallbackFunction_, self.IsDisplayed_, self.PlotHeights_, self.RowIndexFromChannelIndex_) ;
            self.cancel_() ;
        end
        
        function cancel_(self)
            if ~isempty(self.Figure_) && isvalid(self.Figure_)
                delete(self.Figure_) ;
            end
            self.Figure_ = [] ;
        end
    end
end
