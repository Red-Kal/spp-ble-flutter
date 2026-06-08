package bt.com.ssp_ble;

import android.content.Intent;
import android.net.Uri;
import android.view.View;
import android.widget.EditText;
import android.widget.TextView;

//--------------------------------------------------------------------------
	 public class DialogWrapper {
		    EditText titleField=null;
		    EditText valueField=null;
		    EditText Val1,Val2,Val3;
		    View base=null;
		    
		    DialogWrapper(View base) {
		      this.base=base;
		     // valueField=(EditText)base.findViewById(R.id.setvalue);
				//Val1 = (EditText)base.findViewById(R.id.settitle);
				//Val2 = (EditText)base.findViewById(R.id.setvalue);
				//Val3 = (EditText)base.findViewById(R.id.setvalue2);
				//Val1.setText("");Val2.setText("");Val3.setText("");

				TextView link = base.findViewById(R.id.links);
				if(link != null){
					link.setOnClickListener(new View.OnClickListener() {
						@Override
						public void onClick(View v) {
						DeviceListActivity.goweb();
						}
					});

				}
		    }
		    
		    String getTitle() {
		      return(getTitleField().getText().toString());
		    }
		    
		    float getValue() {
		      return(new Float(getValueField().getText().toString())
		                                                  .floatValue());
		    }

		    public String get_Edittext(int index){
		    	if(index>2)return "";
		    	if(index==0)return Val1.getText().toString();
				if(index==1)return Val2.getText().toString();
				if(index==2)return Val3.getText().toString();
				return "";
			}

		    
		    private void setttext(String str){
		    	TextView mtext=(TextView)base.findViewById(R.id.setttext);
		    	mtext.setText(str);
		    }
		    
		    void setnametext(String str){
		    	EditText mtext=(EditText)base.findViewById(R.id.settitle);
		    	//mtext.setText(str);
		    	mtext.setText(str);
		    }
		    
		    void setvaluetext(String str){
		    	EditText mtext=(EditText)base.findViewById(R.id.setvalue);
		    	//mtext.setText(str);
		    	mtext.setText(str);
		    }
		    
		    EditText getTitleField() {
		      if (titleField==null) {
		        titleField=(EditText)base.findViewById(R.id.settitle);
		      }
		      
		      return(titleField);
		    }
		    
		    EditText getValueField() {
		      if (valueField==null) {
		        valueField=(EditText)base.findViewById(R.id.setvalue);
		      }
		      
		      return(valueField);
		    }
		  }
