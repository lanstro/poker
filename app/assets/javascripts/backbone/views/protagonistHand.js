var app = app || {};

var CARDS_PER_ROW = 8;

app.ProtagonistHandView = Backbone.View.extend({
	el: '#protagonist_cards',

	initialize: function(){

		_.bindAll(this, 'render', 'toggleProtagonist', 'dragDropFinished', 'changedArrangement', 'blankClicked', 'swapCards', 
			'sort', 'sortByVal', 'sortBySuit');
		
		this.subViews=[[],[],[]];
		this.sortMethod = "value";
		this.retries = 0;
		this.toggleProtagonist();
	},

	toggleProtagonist: function(arg){
		var protagonist = app.playerInfoCollection.getProtagonistModel();
		if(protagonist){
		
			this.model = protagonist;
			
			this.createSubViews();
			this.changedArrangement(protagonist);
			this.listenTo(this.model, "change:arrangement", this.changedArrangement);
			
			this.listenTo(app.statusModel, "change:status", this.statusChanged);
			
			this.listenTo(app.pubSub, "blankClicked", this.blankClicked);
			this.listenTo(app.pubSub, "sortByVal", this.sortByVal);  
			this.listenTo(app.pubSub, "sortBySuit", this.sortBySuit);
			
			this.listenTo(app.pubSub, "swapCards", this.swapCards);
			this.listenTo(app.pubSub, "dragDropFinished", this.dragDropFinished);  //incomplete
			this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
			
		}
		else {
			this.stopListening();
			delete this.model;
			this.model = null;
			_.each(this.subViews, function(row){
				_.each(row, function(subView){
					subView.stopListening();
					subView.remove();
					delete subView;
					subView=null;
				});
				delete row;
				row=null;
			});
			this.subViews=[[], [], []];
			this.$el.empty();
			this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
		}
	},
	
	createSubViews: function(){
		for(var i=2; i>= 0; i--){
			for(var j=0; j < CARDS_PER_ROW; j++){
				var cardView = new app.CardView({
					model: new app.Card()
				});
				this.subViews[i].push(cardView);
				this.$el.prepend(cardView.render().$el);
			}
		}
	},
	
	changedArrangement:function(data){
		if(!data.get("protagonist")){
			this.toggleProtagonist();
			return;
		}
		var status = app.statusModel.get("status");
		if(status >= DEALING && status <= ALMOST_SHOWDOWN)
			this.sort();
		else
			this.render();
	},
	
	render: function(){
		var arrangement = this.model.get("arrangement");
		if(!arrangement) arrangement = [ {cards: []}, {cards: []},{cards: []}];
		var whichRow = 0, whichPosition = 0;
		
		_.each(this.subViews, function(row){
			_.each(row, function(subView){
				var card = arrangement[whichRow].cards[whichPosition];
				if(card)
					subView.switchModel(card);
				else if(!subView.isBlank())
					subView.switchModel({human_description: "blank", val: undefined});
				whichPosition++;
			}, this);
			whichRow++;
			whichPosition=0;
		}, this);
	},

	statusChanged: function(data){
		var newStatus = data.get("status");
		switch (newStatus){
			case SHOWDOWN_NOTIFICATION:
				if(!app.playerInfoCollection.getProtagonistModel().get('folded'))
				  this.postHand();
				break;
			case OVERALL_GAINS_LOSSES:
				this.model.set("arrangement", false);
				break;
		}
	},
	

	blankClicked: function(blank){
	
		status = app.statusModel.get("status");
		
		var toMove=[];
		var blankRow = null, counter = 0;
		
		_.each(this.subViews, function(row){
			_.each(row, function(cardView){
				if(cardView.model.get('highlighted'))
					toMove.push(cardView);
				else if(cardView == blank)
					blankRow = counter; 
			});
			counter++;
		});

		if(toMove.length === 0)
			return;
			
		this.switchCards(toMove.pop(), blank);
		
		_.each(this.subViews[blankRow], function(cardView){
			if(toMove.length > 0 && cardView.isBlank() )
				this.switchCards(toMove.pop(), cardView);
		}, this);
	},
		
	switchCards: function(cardView1, cardView2){
		var tempCardAttributes = cardView1.model.toJSON();
		cardView1.switchModel(cardView2.model.toJSON());
		cardView2.switchModel(tempCardAttributes);
	},

	handToPost: function(){
		var result = [[], [], []];
		var whichHand = 0;
		var isCards = false;
		_.each(this.subViews, function(row){
			_.each(row, function(cardView){
				if(!cardView.isBlank()){
					result[whichHand].push(cardView.model.get("val"));
					isCards=true;
				}
			});
			whichHand++;
		});
		if (isCards)
			return result;
		else
			return null;
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
	
	dragDropFinished: function(a, b){
		_.each(this.subViews, function(row){
			_.each(row, function(cardView){
				if(cardView.model.get("val") == a)
					a=cardView;
			});
		});
		console.log(a);
		this.switchCards(a, b);
	},

	swapCards: function(){
		var count = {0: 0, 1:0, 2:0};
		var rowNo = 0;
		
		_.each(this.subViews, function(row){
			_.each(row, function(cardView){
				if(cardView.model.get("highlighted"))
					count[rowNo]++;
			});
			rowNo++;
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
		
		if(tooLong || !shorterRow)
			return; 

		var swapee = null, finished=false;
		
		_.each(this.subViews[longerRow], function(cardView){
			if(!finished && cardView.model.get("highlighted")){
				swapee = _.find(this.subViews[shorterRow], function(cV){
					return cV.model.get("highlighted");
				});
				if(!swapee)
					swapee = _.find(this.subViews[shorterRow], function(cV){
						return cV.isBlank();
					});
				if(swapee)
					this.switchCards(swapee, cardView);
				else
					finished=true;
			}
		}, this);
	},
	
	sort: function(){
		if(!this.model.get("arrangement"))
			return;
		var cards = [];
		_.each(this.model.get("arrangement"), function(row){
			_.each(row.cards, function(card){
				cards.push(card);
			});
		});
		
		var that = this;
		cards=_.sortBy(cards, function(card){
			if(that.sortMethod=="value"){
				var val = card["val"] % 13;
				if(val ===KING)
					val = KING_COMPARATOR;
				else if (val===ACE)
					val = ACE_COMPARATOR;
				return val;
			}
			else
				return (card["val"]-1)%52;
		});
		
		var arrangement = [ cards.slice(0, 3).reverse(), cards.slice(3, 8).reverse(), cards.slice(8, 13).reverse()]
		var i=0, j=0;

		for(i = 0; i<3; i++){
			for(j = CARDS_PER_ROW-1; j >= 0; j--){
				var subView = this.subViews[i][j];
				if(arrangement[i][j])
					subView.switchModel(arrangement[i][j]);
				else if(!subView.isBlank())
					subView.switchModel({human_description: "blank", val: undefined});
			}
		}
	},
	
	sortByVal: function(){
		if(this.sortMethod === "suit")
			this.sortMethod = "value";
		this.sort();
	},
	
	sortBySuit: function(){
		if(this.sortMethod === "value")
			this.sortMethod = "suit";
		this.sort();
	},
		
/*
	
	evaluateSubhand: function(whichHand){
	
		var cards = this.partitionSubhands()[whichHand];
		
		var suited = {};
		var multiples = {};
		var values = [];
		
		_.each(cards, function(card){
			var suit = card.get("suit");
			if(!suited[suit]){
				suited[suit]=1;
			}
			else{
				suited[suit]+=1;
			}
			var val = card.valueComputed();
			if(!multiples[val]){
				multiples[val]=1;
			}
			else{
				multiples[val] += 1;
			}
			values.push(val);
		});
		
		var loHand = false;
		if((whichHand === MID_HAND) && MID_IS_LO){
			loHand = true;
		}
	
		// if it's not a lo hand and it's not the front, work out whether the hand is suited
		
		if (!loHand && whichHand != FRONT_HAND && (_.size(suited) === 1)){
			suited = true;
		}
		else {
			suited = false;
		}

		// if it's not a lo hand and it's not the front, work out whether the hand is a straight

		var isStraight = false;
		
		if (!loHand && whichHand != FRONT_HAND && (_.size(multiples) === _.size(cards))){  
			if ( ( (_.last(values) - values[0]) === _.size(values)-1) ||
				(_.last(values) === ACE_COMPARATOR && values[values.length-1] === 5)){
				isStraight=true;
			}
		}
		
		var handName=HIGH_CARD;
		
		// name straights and straight flushes.  
		
		if (isStraight){
		
			if (suited){
				handName = STRAIGHT_FLUSH;
			}
			else {
				handName = STRAIGHT;
			}
		}
		else {
		
			// name hands with repeated cards
		
			switch (_.max(_.values(multiples))){
				case 5:
					handName = FIVE_OF_A_KIND;
					break;
				case 4:
					handName = FOUR_OF_A_KIND;
					break;
				case 3:
					if (_.size(multiples) === 2){
						handName = FULL_HOUSE;
					}
					else {
						handName = THREE_OF_A_KIND;
					}
					break;
				case 2:
					if (_.size(multiples) === 3){
						handName = TWO_PAIR;
					}
					else{
						handName = PAIR;
					}
					break;
			}
		}
					
		// name flushes - done this way as there could be multiple decks
					
		if (suited && (handName < FLUSH)){
			handName = FLUSH;
		}
		
		humanName="";
		
		if (!loHand){
			humanName = ["high card", "pair", "two pair", "three of a kind", "straight", "flush", "full house", 
				"four of a kind", "five of a kind", "straight flush"][handName];
		}
		else {
			if(handName == HIGH_CARD){
				humanName = "lo -";
			}
			else{
				humanName = "compromised lo with "+["high card", "pair", "two pair", "three of a kind", "straight", "flush", 
					"full house", "four of a kind", "five of a kind"][handName];
			}
		}
		
		var order = [];
		var result = {};
		
		switch (handName){
			case FIVE_OF_A_KIND:
				result={value: handName, humanName: humanName+" "+cards[0].get("face_value_long")+"s"};
				break;
			case HIGH_CARD:
			case STRAIGHT:
			case FLUSH:
			case STRAIGHT_FLUSH:
				cards = _.sortBy(cards, function(card){ return card.valueComputed(loHand); }).reverse();
				var cardNames = ""
				humanName+=" ";
				_.each(cards, function(card){ humanName=humanName+card.get("face_value_short");});
				result= {value: handName, humanName: humanName };
				break;
			case PAIR:
			case THREE_OF_A_KIND:
			case FOUR_OF_A_KIND:
			case FULL_HOUSE:
				var mostRepeats=0;
				var valueOfMostRepeats=0;
				_.each(multiples, function(repeats, faceValue){
					if(repeats > mostRepeats){
						mostRepeats = repeats;
						valueOfMostRepeats = faceValue;
					}
				});
				temp=[];
				remaining=[];
				_.each(cards, function(card){
					if (card.valueComputed() === parseInt(valueOfMostRepeats)){
						temp.push(card);
					}
					else{
						remaining.push(card);
					}
				});
				
				remaining=_.sortBy(remaining, function(card){ card.valueComputed(loHand) }).reverse();
				cards=temp.concat(remaining);
				switch (handName){
					case FULL_HOUSE:
						humanName = humanName + " " + cards[0].get("face_value_long")+"s over "+ 
							_.last(cards).get("face_value_long")+"s";
						break;
					case FOUR_OF_A_KIND:
					case THREE_OF_A_KIND:
						humanName = humanName + " "+cards[0].get("face_value_long")+"s";
						break;
					case PAIR:
						humanName = humanName + " of "+cards[0].get("face_value_long")+"s "
						if (loHand){
							humanName += "and "
							_.each(_.rest(cards, 2), function(card){
								humanName+=card.get("face_value_short");
							});
						}
						else{
							humanName += "with "+cards[2].get("face_value_long")+" kicker";
						}
						break;
				}
				result= { value: handName,  humanName: humanName};
				break;
			case TWO_PAIR:
				var higher= 0;
				var lower = 0;
				multiples = {};
				_.each(values, function(v){
					if(!multiples[v]){
						multiples[v]=1;
					}
					else{
						multiples[v] += 1;
					}
					if (multiples[v] == 2){
						if (v > higher){
							lower = higher;
							higher = v;
						}
						else{
							lower = v;
						}
					}
				});
				
				temp = [[], []];
				
				_.each(cards, function(card){
					if (card.valueComputed() === higher){
						temp[0].push(card);
					}
					else if (card.valueComputed()===lower){
						temp[1].push(card);
					}
					else {
						temp.push(card);
					}
				});
				
				cards=_.flatten(temp);
				
				humanName = humanName+", "+cards[0].get("face_value_long")+"s and "+cards[2].get("face_value_long")+"s"
				
				result= {value: handName, humanName: humanName}
				
		}
		var uniqueValue = result["value"].toString(16);
		_.each(cards, function(card){
			uniqueValue+=card.valueComputed(loHand).toString(16)
		});
		result["uniqueValue"]=parseInt(uniqueValue, 16);
		return result;
	}
	

	handNumbersValid: function(whichHand){
	
		var positions = [0, 0, 0];
		
		_.each(this.model.models, function(card){
			positions[card.get('row')]++;
		});
		
		if(typeof whichHand === "undefined"){
			if(this.model.partitionSubhands().join(',') === [3, 5, 5].join(',')){
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
		if(this.model.evaluateSubhand(FRONT_HAND)["uniqueValue"] > this.model.evaluateSubhand(BACK_HAND)["uniqueValue"]){
			return false;
		}
		return true;
	},
*/

});