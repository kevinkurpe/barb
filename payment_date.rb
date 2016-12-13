require 'bigdecimal'

def process_payment_dates
	find_by_batch

	# This is used to mark the record's Date Processed.
	@today = Time.new

	# This outputs the batch id. It's used to display acts as the header or beginning of the process
	puts "\n\n\n\n\n"
	puts "----------------------------------------"
	puts "[DATABASE] #{@database}"
	puts "[BATCH] #{@batch}"
	puts "[TIMESTAMP] #{Time.now.utc.iso8601}"
	puts "----------------------------------------"

	# SET the GL Codes.
	@step0 = set_gl_codes

	@payment_dates.each do |pd|
		@payment_date = pd
		# These "steps" are for clarity sake.
		# Later, these objects could be saved somewhere to log the steps of each batch when it's run.
		if @database == "PTD" || @database == "BC"
			@step1 = load_payment_date
		elsif @database == "DL"
			@step1 = load_dialer_payment_date
		end

		@step2 = process_or_skip
		@step3 = log_result_to_console
		@step4 = update_payment_date
		@step5 = create_payment_processor_log
		@step6 = clear_response
	end

	# This final step calls a script in either the Data File or PTD17 which in turn calls a Payment Processor Tool script in the Payment Processor application file.
	if @database == "PTD"
		@step7 = PTDPaymentDate.find({:_kF_PaymentBatch => @batch}, :post_script => ["PaymentProcessorCallBack", "#{@batch}\nInitiate from Ruby\nPTD"])
	elsif @database == "BC"
		@step7 = BCPaymentDate.find({:_kF_PaymentBatch => @batch}, :post_script => ["PaymentProcessorCallBack", "#{@batch}\nInitiate from Ruby\nBC"])
	elsif @database == "DL"
		@step7 = DialerPaymentDate.find({:_kF_PaymentBatch => @batch}, :post_script => ["PaymentProcessorCallBack", "#{@batch}\nInitiate from Ruby\nDL"])
	end
end

def find_by_batch
	if @database == "PTD"
		@payment_dates = PTDPaymentDate.find(:_kF_PaymentBatch => @batch)
	elsif @database == "BC"
		@payment_dates = BCPaymentDate.find(:_kF_PaymentBatch => @batch)
	elsif @database == "DL"
		@payment_dates = DialerPaymentDate.find(:_kF_PaymentBatch => @batch)
	end
end

def load_payment_date
	@payment_date_id = @payment_date["__kP_PaymentDate"]
	@serial = @payment_date["_Serial"].to_i
	@directory_id = @payment_date["_kF_Directory"]
	@payment_method_id = @payment_date["_kF_PaymentMethod"]

	@customer_token = @payment_date["T54_DIRECTORY::Token_Profile_ID"]
	@payment_token = @payment_date["T54_PAYMENTMETHOD::Token_Payment_ID"]

	# Credit Card values.
	@cardnumber = @payment_date["T54_PAYMENTMETHOD::CreditCard_Number"]
	@carddate = @payment_date["T54_PAYMENTMETHOD::MMYY"]
	@cardcvv = @payment_date["T54_PAYMENTMETHOD::CVV"]

	@amount = @payment_date["Amount"].to_f

	if @database == "BC"
		@bc = @payment_date["T54_LINK::zzC_BC_Location_ABBR"]
		# @bc = @payment_date["T54_DIRECTORY::zzC_Location_ABBR"] # Once BC17 goes live, this field will need to be used.
	end

end

def load_dialer_payment_date
	@payment_date_id = @payment_date["__kP_Payment"]
	@serial = @payment_date["_Serial"].to_i
	@lead_id = @payment_date["_kF_DialerLead"]
	@guest_id = @payment_date["_kF_Guest"]
	@payment_method_id = @payment_date["_kF_PaymentMethod"]

	@customer_token = @payment_date["DialerLeads::Token_Profile_ID"]
	@payment_token = @payment_date["PaymentMethod::Token_Payment_ID"]
	@amount = @payment_date["Amount"].to_f
end

def update_payment_date

		if @resultCode == "OK"

			# RECORD the Date Processed.
			if @database == "PTD" || @database == "BC"
				@payment_date[:Date_Processed] = @today
			end

			# SAVE the response values for all transactions.
			@payment_date[:zzPP_Transaction] = @transactionID
			@payment_date[:zzPP_Response] = @theResponse
			@payment_date[:zzPP_Response_AVS_Code] = @avsCode
			@payment_date[:zzPP_Response_CVV_Code] = @cvvCode
			@payment_date[:zzPP_Response_Code] = @responseCode

			# These transaction WERE processed.
			if @responseKind == "Approved"
				@payment_date[:zzF_Status] = "Approved"
				@payment_date[:zzPP_Authorization_Code] = @authorizationCode
				@payment_date[:zzPP_Response_Message] = @responseMessage

			elsif @responseKind == "Declined"
				@payment_date[:zzF_Status] = "Declined"
				@payment_date[:zzPP_Response_Error] = @responseError

			elsif @responseKind == "Error"
				@payment_date[:zzF_Status] = "Error"
				@payment_date[:zzPP_Response_Error] = @responseError

			elsif @responseKind == "HeldforReview"
				@payment_date[:zzF_Status] = "HeldForReview"
				@payment_date[:zzPP_Response_Error] = @responseError
			end

		elsif @resultCode == "ERROR"

			# Regardless of the type of error, set the PaymentDate Status to Error.
			@payment_date[:zzF_Status] = "Error"

			# These transaction were NOT processed.
			if @responseKind == "TransactionError"
				@payment_date[:zzPP_Transaction] = @transactionID
				@payment_date[:zzPP_Response] = @theResponse
				@payment_date[:zzPP_Response_Code] = @responseCode
				@payment_date[:zzPP_Response_Error] = @responseError

			elsif @responseKind == "TokenError"
				@payment_date[:zzPP_Response] = @theResponse
				@payment_date[:zzPP_Response_Code] = @responseCode
				@payment_date[:zzPP_Response_Error] = @responseError

			# This transaction was NOT sent to Authorize.net successfully.
			elsif @responseKind == "TransactionFailure"
				@payment_date[:zzPP_Response_Error] = @responseError
			end

		end

		# SAVE the changes to the database.
		@payment_date.save

end
