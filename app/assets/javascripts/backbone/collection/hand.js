var app = app || {};

app.Hand = Backbone.Collection.extend({
	model: app.Card,
	sortMethod: "value",
	
	initialize: function(){
		this.url=$('#table').data('table_id')+'/protagonist_cards';
		this.fetch();
		console.log("cards collection initialized");
		_.bindAll(this, 'sortByVal', 'sortBySuit');
		this.listenTo(window.pubSub, "sortByVal", this.sortByVal);
		this.listenTo(window.pubSub, "sortBySuit", this.sortBySuit);
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
	
	handNumbersValid: function(){
		
		var positions = [0, 0, 0];
		
		_.each(this.models, function(card){
			positions[card.get('row')]++;
		});
		if(positions.join(',') === [3, 5, 5].join(',')){
			return true;
		}
		return false;
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
	
	handValue: function(whichHand){
	
		if(whichHand === MID_HAND && MID_IS_LO){
			return this.calcLoHandValue(whichHand);
		}
		else{
			return this.calcHiHandValue(whichHand);
		}
		
	},
	/*
	calcHiHandValue: function(whichHand){
		var isSuited = true;
		var suit;
		var values=this.models.filter(function(card){
				return card.get('row')===whichHand;
			}).map( function(card){
				suit = suit || card.suit;
				if(suit != card.suit){
					isSuited=false;
				}
				return card.valueComputed();
			}).sort(function(a,b){return a-b});
		
		var multiples=_.countBy(this.models, function(card){
			return card.valueComputed();
		});
		
		var numberUniqueValues = _.size(multiples);
		
		var isStraight = false;
		
		if(numberUniqueValues === values.length){
			if(_.last(values) - values[0] === values.length-1){
				isStraight=true;
			}
			else if(_.last(values) === ACE_COMPARATOR){
				var temp=values.slice();
				temp[temp.length-1]=1;
				temp.sort(function(a,b){return a-b});
				if(_.last(temp) - temp[0] == temp.length-1){
					isStraight=true;
				}
			}
			if(!isStraight && !isSuited){
				console.log("is a hi card");
				return HI_CARD;
			}
		}
		
		if(isSuited && isStraight){
			return STRAIGHT_FLUSH;
		}
		else if(isStraight){
			return STRAIGHT;
		}
		switch(_.max(_.values(multiples))){
			case 5:
				return FIVE_OF_A_KIND;
			case 4:
				return FOUR_OF_A_KIND;
			case 3:
				if(numberUniqueValues===2){
					return FULL_HOUSE;
				}
				else if(isSuited){
					return FLUSH;
				}
				else{
					return THREE_OF_A_KIND;
				}
			case 2:
				if(isSuited){
					return FLUSH;
				}
				else if(numberUniqueValues===3){
					return TWO_PAIR;
				}
				else
					return PAIR;
		}
		if(isSuited){
			return FLUSH;
		}
		
		return null;
	},
	
	calcLoHandValue: function (whichHand){
		var values=_.uniq(this.models.map( function(model, key){
			return model.valueComputed();
		})).sort(function(a,b){return a-b});
		return values.join("");
	}
*/
});