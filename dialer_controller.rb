def process_create_dialer_payment_method_request
	parse_create_dialer_payment_method_post
	if @request_type == "Charge"
		create_dialer_tokens
		if @responseKind == "OK"
			process_dialer_payment_date
		end
	elsif @request_type == "Schedule"
		create_dialer_tokens
		if @responseKind == "OK"
			save_scheduled_dailer_payment_date
		end
	end

end

def process_create_dialer_payment_date_request
	parse_create_dialer_payment_method_post
	if @request_type == "Charge"
		load_dialer_tokens
		process_dialer_payment_date
	elsif @request_type == "Schedule"
		load_dialer_tokens
		save_scheduled_dailer_payment_date
	end

end

def parse_create_dialer_payment_method_post
	@lead_id = params[:lead_id]
	@guest_id = params[:guest_id]
	@payment_method_id = params[:payment_method_id]
	@request_type = params[:request_type] #Charge or Schedule

	# Grab the values from the POST object.
	@date = params[:Date]
	@amount = params[:Amount]
	
	@namefirstCC = params[:Name_First]
	@namelastCC = params[:Name_Last]
	@cardnumber = params[:CreditCard]
	@carddate = params[:MMYY]
	@cardcvv = params[:CVV]
	@address = params[:Address_Address]
	@city = params[:Address_City]
	@state = params[:Address_State]
	@zip = params[:Address_Zip]

	log_post_variables_to_console
end

def log_post_variables_to_console
	puts "\n\n\n\n\n"
	puts "----------------------------------------"
	puts "[POST VALUES]"
	puts "----------------------------------------"
	puts "[LEAD] #{@lead_id}"
	puts "[GUEST] #{@guest_id}"
	puts "[PM] #{@payment_method_id}"
	puts "[TYPE] #{@request_type}" #Charge or Schedule

	# Grab the values from the POST object.
	puts "[DATE] #{@date}"
	puts "[AMOUNT] #{@amount}"
	
	puts "[FIRST] #{@namefirstCC}"
	puts "[LAST] #{@namelastCC}"
	puts "[CARD] #{@cardnumber}"
	puts "[DATE] #{@carddate}"
	puts "[CVV] #{@cardcvv}"
end

def load_dialer_tokens
	# if @recordtype == "DialerLead"
		find_dialer_lead
		find_dialer_payment_method
	# elsif @recordtype == "DialerGuest"
	# 	find_dialer_guest
	# 	find_dialer_payment_method
	# end
end

def create_dialer_tokens
	create_dialer_lead_customer_token
	if @responseKind == "OK"
		create_dialer_payment_token
	elsif @dialer_lead_found == true && @has_customer_token == true
		create_dialer_payment_token
	end
end

def process_dialer_payment_date
	@step0 = set_gl_codes
	@step1 = card_or_token
	@step2 = process_payment
	@step3 = log_result_to_console
	@step4 = save_processed_dailer_payment_date
	@step5 = set_response
	# @step6 = clear
end
