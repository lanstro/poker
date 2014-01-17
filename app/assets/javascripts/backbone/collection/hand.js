var app = app || {};

app.Hand = Backbone.Collection.extend({
	model: app.Card,
	sortMethod: "value",
	
	initialize: function(){
		this.url=$('#table').data('table_id')+'/protagonist_cards';
		this.fetch();
		//console.log("cards collection initialized");
		_.bindAll(this, 'sortByVal', 'sortBySuit', 'recalcHands');
		this.listenTo(window.pubSub, "sortByVal", this.sortByVal);
		this.listenTo(window.pubSub, "sortBySuit", this.sortBySuit);
		this.listenTo(window.pubSub, "protagonistHandRendered", this.recalcHands);
	},
	
	sortByVal: function(){
		if(this.sortMethod === "suit"){
			this.sortMethod = "value";
		}
		this.sort();
	},
	
	sortBySuit: function(){
		if(this.sortMethod === "value"){
			this.sortMethod = "suit";
		}
		this.sort();
	},

	comparator: function(card){
		if(this.sortMethod === 'suit'){
			return card.get('suit');
		}
		else {
			return card.valueComputed();
		}
	},
	
	recalcHands: function(){
		var descriptions= ["Invalid", "Invalid", "Invalid"];
		for(i=0; i<3; i++){
			if(this.handNumbersValid(i)){
				descriptions[i] = this.evaluateSubhand(i)["humanName"];
			}
		}
		window.pubSub.trigger("protagonistHandDescriptionsUpdated",  descriptions);
	},
	
	partitionSubhands: function(){
		
		result = [[], [], []];
		_.each(this.models, function(card){
			result[card.get("row")].push(card);
		});
		return result;
	},
	
	handNumbersValid: function(whichHand){
	
		var positions = [0, 0, 0];
		
		_.each(this.models, function(card){
			positions[card.get('row')]++;
		});
		
		if(typeof whichHand === "undefined"){
			if(this.partitionSubhands().join(',') === [3, 5, 5].join(',')){
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
		if(this.handValue(FRONT_HAND) > this.handValue(BACK_HAND)){
			return false;
		}
		return true;
	},
	
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
				cards = _.sortBy(cards, function(card){ card.valueComputed(loHand); }).reverse();
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
});