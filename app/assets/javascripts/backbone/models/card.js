var app = app || {};

app.Card = Backbone.Model.extend ({
	defaults: {
		val: null
	},
	initialize: function(){
		this.set('val',Math.floor(Math.random()*52)+1);
		this.suit = ["c", "s", "h", "d"][Math.floor((this.get('val')-1)/13)];
	},
	valueHuman:function(){
		var result = this.get('val')%13;
		switch(result){
			case ACE:
				result='A';
				break;
			case TEN:
				result='T';
				break;
			case JACK:
				result='J';
				break;
			case QUEEN:
				result='Q';
				break;
			case KING:
				result='K';
				break;
		}
		return result;
	},
	JSON_value: function(){
		if(!this.get('val')){
			return ({value_string:'blank'});
		}
		return ({value_string: this.valueHuman()+this.suit});
	},
	valueComputed: function(){
		var result = this.get('val') % 13;
		if (result === KING){
			result = KING_COMPARATOR;
		}
		else if (result === ACE){
			result = ACE_COMPARATOR;
		}
		return result;
	},

});