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
			this.sort();
		}
	},
	
	sortBySuit: function(){
		if(this.sortMethod === "value"){
			this.sortMethod = "suit";
			this.sort();
		}
	},

	comparator: function(card){
		if(this.sortMethod === 'suit'){
			return card.get('suit');
		}
		else {
			console.log('comparator called on '+JSON.stringify(card));
			result = card.get('val') % 13;
			if (result === KING) {
				result = KING_COMPARATOR;
			}
			else if (result === ACE) {
				result = ACE_COMPARATOR;
			}
			console.log('comparator going to return '+result);
			return result;
		}
	},
	
/*
	
	comparator: function(a, b){
		// console.log("Comparing "+a.JSON_value().value_string+" with "+b.JSON_value().value_string);
		
		a = a.valueComputed();
		b = b.valueComputed();
		
		if(a > b){
			//console.log(1);
			return 1;
		}
		else if (a===b){
			//console.log(0);
			return 0;
		}
		else {
			//console.log(-1);
			return -1;
		}
	},
	
	handValid: function(){
		if(this.handPosition === FRONT_HAND){
			if(this.length != 3){
				return false
			}
		}
		else if (this.length != 5){
			return false
		}
		return true;
	},
	
	handValue: function(){
		if(!this.handValid()){
			return null;
		}
		if(this.handPosition === MID_HAND && MID_IS_LO){
			return this.calcLoHandValue();
		}
		else{
			return this.calcHiHandValue();
		}
		
	},
	
	calcHiHandValue: function(){
		var isSuited = true;
		var suit;
		var values=this.models.map( function(model, key){
			suit = suit || model.suit;
			if(suit != model.suit){
				isSuited=false;
			}
			return model.valueComputed();
		}).sort(function(a,b){return a-b});
		
		var multiples=_.countBy(this.models, function(model){
			return model.valueComputed();
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
	
	calcLoHandValue: function (hand){
		var values=_.uniq(this.models.map( function(model, key){
			return model.valueComputed();
		})).sort(function(a,b){return a-b});
		return values.join("");
	}
	
*/
	
});