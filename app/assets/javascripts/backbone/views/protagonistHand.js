var app = app || {};

app.ProtagonistHandView = Backbone.View.extend({
	el: '#protagonist_cards',
	initialize: function(){

		_.bindAll(this, 'render', 'toggleProtagonist', 'dragDropFinished');
		
		this.retries = 0;
		this.toggleProtagonist();
	},

	toggleProtagonist: function(arg){
		var protagonist = app.playerInfoCollection.getProtagonistModel();
		console.log("hand listener heard protagonist change with arg "+JSON.stringify(arg));
		if(protagonist){
			this.collection= new app.Hand();
			this.listenTo(this.collection, "sort", this.sorted);
			this.collection.reset(protagonist.cards());
			
			this.listenTo(app.statusModel, "change:status", this.statusChanged);
			
			this.listenTo(app.pubSub, "blankClicked", this.blankClicked);
			this.listenTo(app.pubSub, "sortByVal", this.collection.sortByVal);
			this.listenTo(app.pubSub, "sortBySuit", this.collection.sortBySuit);
			
			this.listenTo(app.playerInfoCollection.getProtagonistModel(), "change:arrangement", this.changedArrangement);
			
			this.listenTo(app.pubSub, "swapCards", this.swapCards);
			this.listenTo(app.pubSub, "dragDropFinished", this.dragDropFinished);
			this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
			
			this.sorted();
		}
		else {
			this.stopListening();
			delete this.collection;
			this.collection = null;
			this.$el.empty();
			this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
		}
	},
	
	changedArrangement:function(data){
		console.log("protagonist arrangement change detected");
		if(!data.get("protagonist"))
			return;
		var cards = app.playerInfoCollection.getProtagonistModel().cards();
		if(cards){
			this.collection.reset(cards);
			this.sorted();
		}
	},

	blankClicked: function(row, position){
		status = app.statusModel.get("status");
		if(status < DEALING || status > ALMOST_SHOWDOWN){
			return;
		}
	
		var blanks = [position].concat(_.without([0, 1, 2, 3, 4, 5, 6, 7], position));
		var toMove=[];
		
		_.each(this.collection.models, function(card){
			if(card.get('highlighted')){
				toMove.push(card);
			}
			else if(card.get('row') === row){
				blanks=_.without(blanks, card.get('position'));
			}
		});

		if(toMove.length === 0){
			return;
		}

		_.each(blanks, function(position){
			if(toMove.length > 0){
				var card = toMove.pop();
				card.set({"row": row, "position": position, "highlighted": false});
			}
		}, this);
		this.render();
	},
	
	sorted: function(){
		console.log("protagonist hand sorted");
		var row=0;
		var cards_in_current_row=0;
		var layout=[3, 5, 5];
		
		_.each(this.collection.models, function(model){
			model.set({'row'		 		: row, 
								 'position'		: layout[row] - cards_in_current_row - 1,
								 'highlighted': false});
			cards_in_current_row++;
			if(cards_in_current_row >= layout[row]){
				row++;
				cards_in_current_row=0;
			}
		}, this);
		this.render();
	},

	statusChanged: function(data){
		var newStatus = data.get("status");
		switch (newStatus){
			case DEALING:
			case FOLDERS_NOTIFICATION:
			case SHOWING_DOWN_FRONT_NOTIFICATION:
			case SHOWING_DOWN_MID_NOTIFICATION:
			case SHOWING_DOWN_BACK_NOTIFICATION:
			case OVERALL_SUGAR:
			case OVERALL_GAINS_LOSSES:
				this.render();
				break;
		}
		if (newStatus === SHOWDOWN_NOTIFICATION && !app.playerInfoCollection.getProtagonistModel().get('folded'))
			this.postHand();
		if (newStatus === OVERALL_GAINS_LOSSES)
			this.collection.reset();
	},
	
	render: function(){
		
		if(!this.collection){
			return this;
		}
	
		var status = app.statusModel.get("status");
		this.$el.empty();
		
		// somewhere else - if it's beyond folders_notification, use the playersInfo arrangement instead
		
		if(this.collection.models.length === 0 || status < DEALING || status > BACK_HAND_SUGAR){
			this.renderRow([false, false, false]);
		}
		else if(status >= SHOWING_DOWN_FRONT_NOTIFICATION && status <= FRONT_HAND_SUGAR){
			this.renderRow([true, false, false]);
		}
		else if(status >= SHOWING_DOWN_MID_NOTIFICATION && status <= MID_HAND_SUGAR){
			this.renderRow([false, true, false]);
		}		
		else if(status >= SHOWING_DOWN_BACK_NOTIFICATION && status <= BACK_HAND_SUGAR){
			this.renderRow([false, false, true]);
		}
		else {
			this.renderRow([true, true, true]);
		}
		return this;
	},
	
	
	renderRow: function(whichRows){

		for(var row = 2; row >= 0 ; row--){
			var cardsInRow = this.collection.models.filter(function(card){
				if(whichRows[row] && card.get('row') === row){
					return true;
				}
			});
			for(var position = 0; position < 8; position++){
				var correctCard = cardsInRow.filter(function(card){
					if(card.get('position') === position){
						return true;
					}
				});
				if(correctCard.length === 1 ){
					this.renderCard(correctCard[0]);
				}
				else{
					this.renderCard( new app.Card({
						human_description: "blank",
						position: position,
						row: row
					}));
				}
			}
		}
	},
	
	handToPost: function(){
		var result = [[], [], []];
		if(this.collection.size() === 0){
			return;
		}
		_.each(this.collection.models, function(card){
			result[card.get("row")].push(card.get("val"));
		});
		return result;
	},
	
	postHand: function(){
		var data = this.handToPost();
		if(!data)
			return;
		var retries = 0;
		var that = this;
		
		app.pubSub.trigger("allowedToAdvanceStatus", false);
		$("#announcements").addClass("loading");
		
		$.ajax({
			type: "POST",
			url: $('#table').data('table_id')+"/post_protagonist_cards", 
			dataType: "json",
			data: JSON.stringify({arrangement: data}), 
			contentType: 'application/json',
			timeout: 2000 + that.retries *1000,
			error: function(xhr, textStatus, errorThrown){
				if(textStatus == "timeout"){
					if(that.retries > 2){
						bootbox.alert("Your connection to the server is very poor, and we have failed to post your hand.  Your hand has been automatically arranged, and you have been set to sitting out the next hand.");
						app.pubSub.trigger("allowedToAdvanceStatus", true);
						app.playerInfoCollection.getProtagonistModel().set("sitting_out", true);
						that.retries = 0;
						return;
					}
					else{
						that.retries+=1;
						that.postHand();
					}
				}
			},
			success: function(data){
				app.pubSub.trigger("allowedToAdvanceStatus", true);
				$("#announcements").removeClass("loading");
				that.retries = 0;
			}
		});
	},
	
	renderCard: function(card){
		var cardView=new app.CardView({
			model:card,
		});
		this.$el.prepend(cardView.render().$el);
	},
	
	dragDropFinished: function(a, b){
		console.log("dragdropfinished called"+JSON.stringify(a)+JSON.stringify(b));
		a=this.collection.where({val: parseInt(a)})[0];
		console.log(a);
		this.switchCards(a, b);
		this.render();
	},
		
	switchCards: function(a, b){
		var aPosition = a.get('position'),
				aRow      = a.get('row');
		a.set({ position: b.get('position'), row: b.get('row'), highlighted: false });
		b.set({ position: aPosition, row: aRow, highlighted: false });
	},

	swapCards: function(){
		
		var grid = [ [], [], [] ];
		var count = {0: 0, 1:0, 2:0};
		
		this.collection.each(function(card){
			if(card.get("highlighted")){
				var row = card.get('row');
				grid[row][card.get('position')] = card
				count[row]++;
			}
			else {
				grid[card.get('row')][card.get('position')] = "taken"
			}
		});
		
		var highest = 1, lower = 1, longerRow = null, shorterRow = null, tooLong=false;
		
		_.each(count, function(val, key){
			
			if(val >= lower){
				if(shorterRow){
					tooLong=true;
					return
				}
				if(val >= highest){
					highest=val;
					shorterRow = longerRow;
					longerRow = key;
				}
				else {
					shorter = val;
					shorterRow = key;
				}
			}
		});
		
		if(tooLong || !shorterRow){
			this.collection.each(function(card){
				if(card.get("highlighted")){
					card.set({ highlighted: false });
				}
			});
			return; 
		}

		_.each(grid[longerRow], function(card){
			if(card != "taken" && card.get("highlighted")){
				var swapee = _.find(grid[shorterRow], function(card){
					if(card != null && typeof card != 'undefined' && card != "taken" && card.get("highlighted")){
						return true;
					}
				});
				if(typeof swapee != 'undefined'){
					this.switchCards(card, swapee);
					grid[shorterRow][card.get("position")]="taken";
					return;
				}
				else{
					var position = _.find([0, 1, 2, 3, 4, 5, 6, 7], function(position){
						return grid[shorterRow][position] == null || grid[shorterRow][position] == undefined;
					});
					if(typeof position != 'undefined'){
						card.set( {row: parseInt(shorterRow), position: position, highlighted: false});
						grid[shorterRow][position]="taken";
						return;
					}
					else {
						card.set({highlighted: false});
					}
				}
			}
		}, this);
		this.render();
	},
/*
	handNumbersValid: function(whichHand){
	
		var positions = [0, 0, 0];
		
		_.each(this.collection.models, function(card){
			positions[card.get('row')]++;
		});
		
		if(typeof whichHand === "undefined"){
			if(this.collection.partitionSubhands().join(',') === [3, 5, 5].join(',')){
				return true;
			}
			return false;
		}
		if(positions[whichHand] !== [3, 5, 5][whichHand]){
			return false;
		}
		return true;
	},
	
	handValid: function(){
		if(!this.handNumbersValid()){
			return false;
		}
		if(this.collection.evaluateSubhand(FRONT_HAND)["uniqueValue"] > this.collection.evaluateSubhand(BACK_HAND)["uniqueValue"]){
			return false;
		}
		return true;
	},
*/
});