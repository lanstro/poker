var app = app || {};

app.ProtagonistHandView = Backbone.View.extend({
	el: '#protagonist_cards',
	initialize: function(){
		var col = new app.Hand();
		col.url=$('#table').data('table_id')+'/protagonist_cards';
		col.fetch();
		this.collection= col;

		_.bindAll(this, 'render', 'recalcHands');
		//this.listenTo(col, "all", this.eventTracker);
		this.listenTo(col, "sort", this.sorted);
		this.listenToOnce(app.pubSub, 'statusChanged', this.render);
		this.listenTo(app.pubSub, "blankClicked", this.blankClicked);
		this.listenTo(app.pubSub, "sortByVal", this.collection.sortByVal);
		this.listenTo(app.pubSub, "sortBySuit", this.collection.sortBySuit);
		//this.listenTo(app.pubSub, "protagonistHandRendered", this.recalcHands);
		this.listenTo(app.pubSub, "statusChanged", this.statusChanged);
		this.listenTo(app.pubSub, "swapCards", this.swapCards);
	},

	blankClicked: function(row, position){
	
		if(app.status() < DEALING || app.status() > ALMOST_SHOWDOWN){
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

	statusChanged: function(newStatus){
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
		if(newStatus == DEALING){
			this.collection.fetch();
		}
		if (newStatus === SHOWDOWN_NOTIFICATION){
			this.postHand();
		}
		if (newStatus === OVERALL_GAINS_LOSSES){
			this.collection.reset();
		}
	},
	
	render: function(){
	
		var status = app.status();
		this.$el.empty();
		
		if(this.collection.models.length === 0 || status < DEALING || status > BACK_HAND_SUGAR){
			this.renderRow([false, false, false]);
		}
		else if(status >= DEALING && status <= FOLDERS_NOTIFICATION){
			this.renderRow([true, true, true]);
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
		app.pubSub.trigger("protagonistHandRendered");
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
	
	postHand: function(){
		result = [[], [], []];
		if(this.collection.size() === 0){
			return;
		}
		_.each(this.collection.models, function(card){
			result[card.get("row")].push(card.get("val"));
		});
		$.ajax({
			type: "POST",
			url: $('#table').data('table_id')+"/post_protagonist_cards", 
			dataType: "json",
			data: JSON.stringify({arrangement: result}), 
			contentType: 'application/json'
		});
	},
	
	renderCard: function(card){
		var cardView=new app.CardView({
			model:card,
		});
		this.$el.prepend(cardView.render().$el);
	},
		
	switchCards: function(a, b){
		var aPosition = a.get('position'),
				bPosition = b.get('position'),
				aRow      = a.get('row'),
				bRow      = b.get('row');
		a.set({ position: bPosition, row: bRow });
		b.set({ position: aPosition, row: aRow });
	},
	
	swapCards: function(){
	
		console.log("swapCards called");

		this.render();
	},
	
	handDealt: function(cards){
		this.collection.reset(cards.cards);
		this.collection.sort();
	},
	
	recalcHands: function(){
		var descriptions= ["", "", ""];
		for(i=0; i<3; i++){
			if(this.handNumbersValid(i)){
				descriptions[i] = this.collection.evaluateSubhand(i)["humanName"];
			}
		}
		app.pubSub.trigger("protagonistHandDescriptionsUpdated",  descriptions);
	},
	
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

	/*
	eventTracker: function(arg1, arg2){
		console.log("hand view's 'all' event called");
		console.log("event was: "+arg1);
		if(arg2){
			var cache=[];
			console.log("arg2 was "+JSON.stringify(arg2, function(key, value) {
				if (typeof value === 'object' && value !== null) {
						if (cache.indexOf(value) !== -1) {
								// Circular reference found, discard key
								return;
						}
						// Store value in our collection
						cache.push(value);
				}
				return value;
			}));
		}
	},
*/
	
});