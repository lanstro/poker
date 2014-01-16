var app = app || {};

app.Card = Backbone.Model.extend ({
	toggleHighlighted: function(){
		if(this.get('highlighted')){
			this.set('highlighted', false);
		}
		else{
			this.set('highlighted', true);
		}
	}
	/*
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
			return ({human_description:'blank'});
		}
		return ({human_description: this.valueHuman()+this.suit});
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
	*/
});