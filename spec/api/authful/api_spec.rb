require 'spec_helper'

describe Authful::API do

  before :all do
    @user = create(:user)
    @account = @user.account
  end

  it "returns 401 for bad api tokens" do
    user_count_changes_by(0) do
      post "/api/users", {email: "john.doe@gmail.com", phone: "1205555434"}, {"Api-Token" => "NotAToken"}

      response.status.should eq(401)

      r = JSON.parse(response.body)
      r["error"].should_not be_nil
    end
  end

  it "does not return user that does not belong to account" do
    get "/api/users/#{create(:user).token}/send_sms", {}, {"Api-Token" => @account.token}

    response.status.should eq(404)
  end

  it "enrolls a valid app user" do
    user_count_changes_by(1) do
      post "/api/users", {email: "john.doe@gmail.com"}, {"Api-Token" => @account.token}

      response.status.should eq(201)

      r = JSON.parse(response.body)

      u = User.where(email: "john.doe@gmail.com").first
      u.sms_user?.should eq(false)
      r["token"].should eq(u.token)
      r["email"].should eq(u.email)
      r["qr_code"].should_not eq(nil)
      r["phone"].should eq(nil)
    end
  end

  it "enrolls multiple users with '' phone" do
    user_count_changes_by(3) do
      post "/api/users", {email: "jimmy0@gmail.com", phone: ""}, {"Api-Token" => @account.token}
      response.status.should eq(201)
      post "/api/users", {email: "jimmy1@gmail.com", phone: ""}, {"Api-Token" => @account.token}
      response.status.should eq(201)
      post "/api/users", {email: "jimmy2@gmail.com", phone: ""}, {"Api-Token" => @account.token}
      response.status.should eq(201)
    end
  end

  it "enrolls a valid sms user" do
    user_count_changes_by(1) do
      post "/api/users", {email: "jane.doe@gmail.com", phone: "12055551212"}, {"Api-Token" => @account.token}

      response.status.should eq(201)

      r = JSON.parse(response.body)

      u = User.where(email: "jane.doe@gmail.com").first
      u.sms_user?.should eq(true)
      r["token"].should eq(u.token)
      r["email"].should eq(u.email)
      r["qr_code"].should eq(nil)
      r["phone"].should_not eq(nil)
    end
  end

it "enroll an valid app user with blank sms" do
    user_count_changes_by(1) do
      post "/api/users", {email: "jim.doe@gmail.com", phone: ""}, {"Api-Token" => @account.token}

      response.status.should eq(201)

      r = JSON.parse(response.body)

      u = User.where(email: "jim.doe@gmail.com").first
      u.sms_user?.should eq(false)
      r["token"].should eq(u.token)
      r["email"].should eq(u.email)
      r["qr_code"].should_not eq(nil)
      r["phone"].should eq(nil)
    end
  end

  it "does not enroll an invalid user" do
    user_count_changes_by(0) do
      post "/api/users", {}, {"Api-Token" => @account.token}

      response.status.should eq(400)

      r = JSON.parse(response.body)
      r["error"].should_not be_nil
    end
  end

  it "unenrolls a user" do
    @user_a = create(:user)
    @account_a = @user_a.account

    user_count_changes_by(-1) do
      delete "/api/users/#{@user_a.token}", {}, {"Api-Token" => @account_a.token}

      response.status.should eq(200)

      r = JSON.parse(response.body)
      r["ok"].should eq(1)
    end
  end

  it "doesn't unenroll a user on different account" do
    @user_a = create(:user)
    @account_a = @user_a.account
    @user_b = create(:user)
    @account_b = @user_b.account

    user_count_changes_by(0) do
      delete "/api/users/#{@user_a.token}", {}, {"Api-Token" => @account_b.token}

      response.status.should eq(404)

      r = JSON.parse(response.body)
      r["error"].should eq("404 Not Found")
    end
  end

  it "view a user" do
    get "/api/users/#{@user.token}", {}, {"Api-Token" => @account.token}

    response.status.should eq(200)

    r = JSON.parse(response.body)
    r["email"].should eq(@user.email)
    r["enrollment_type"].should eq("sms")
    r["number"].should eq(@user.phone)
    r["fallback_phone"].should eq(@user.fallback_phone)
  end

  it "shows qr code" do
    @user.activate_qr_code

    get "/qr/#{@user.token}.png", {}, {}

    response.status.should eq(200)
  end

  it "does not show qr code if expired" do
    @user.deactivate_qr_code

    get "/qr/#{@user.token}.png", {}, {}

    response.status.should eq(404)
  end

  it "shows qr code only once" do
    @user.activate_qr_code

    get "/qr/#{@user.token}.png", {}, {}

    response.status.should eq(200)

    get "/qr/#{@user.token}.png", {}, {}

    response.status.should eq(404)
  end

  it "unenrolls valid users" do
    user = create(:user, account: @account)

    user_count_changes_by(-1) do
      delete "/api/users/#{user.token}", {}, {"Api-Token" => @account.token}

      response.status.should eq(200)

      r = JSON.parse(response.body)
      r["ok"].should eq(1)
    end
  end

  it "returns error when trying to unenroll invalid user" do
    user_count_changes_by(0) do
      delete "/api/users/wrongToken", {}, {"Api-Token" => @account.token}

      response.status.should eq(404)

      r = JSON.parse(response.body)
      r["error"].should eq("404 Not Found")
    end
  end

  it "validates correct token" do
    get "/api/users/#{@user.token}/validate", {token: @user.generate_otp}, {"Api-Token" => @account.token}

    response.status.should eq(200)

    r = JSON.parse(response.body)
    r["ok"].should eq(1)
  end

  it "responds with error when invalid token" do
    get "/api/users/#{@user.token}/validate", {token: "000000"}, {"Api-Token" => @account.token}

    response.status.should eq(403)

    r = JSON.parse(response.body)
    r["error"].should eq("invalid token")
  end

  it "send sms to a valid phone number" do
    get "/api/users/#{@user.token}/send_sms", {}, {"Api-Token" => @account.token}

    response.status.should eq(200)

    r = JSON.parse(response.body)
    r["ok"].should eq(1)
  end

  it "send fallback sms to a valid phone number" do
    @user.update_attributes(fallback_phone: @user.phone)
    get "/api/users/#{@user.token}/fallback", {}, {"Api-Token" => @account.token}

    response.status.should eq(200)

    r = JSON.parse(response.body)
    r["ok"].should eq(1)
  end

  it "does not send sms to invalid phone number" do
    user = create(:user, phone: "15005550004", account: @account) # A twilio error number from https://www.twilio.com/docs/api/rest/test-credentials
    get "/api/users/#{user.token}/send_sms", {}, {"Api-Token" => @account.token}

    response.status.should eq(400)

    r = JSON.parse(response.body)
    r["error"].should eq("Message did not send. Twilio returned error code 21610; message: The message From/To pair violates a blacklist rule.")
  end
  
  it "sets a fallback phone number" do
    phone = "12055551212"

    @user.fallback_phone.should_not eq(phone)
    patch "/api/users/#{@user.token}/fallback", {phone: phone}, {"Api-Token" => @account.token}

    response.status.should eq(200)

    r = JSON.parse(response.body)
    r["ok"].should eq(1)
    @user.reload
    @user.fallback_phone.should eq(phone)
  end

  it "does not set an invalid fallback phone number" do
    phone = "1"
    @user.fallback_phone.should_not eq(phone)
    user_field_change(@user, :fallback_phone, false) do
      patch "/api/users/#{@user.token}/fallback", {phone: phone}, {"Api-Token" => @account.token}

      response.status.should eq(400)

      r = JSON.parse(response.body)
      r["error"].should_not eq(nil)
    end
  end

  it "resets a valid user" do
    user = create(:user, account: @account)
    user_field_change(user, :secret, true) do
      patch "/api/users/#{user.token}/reset", {}, {"Api-Token" => @account.token}

      response.status.should eq(200)

      r = JSON.parse(response.body)
      r["email"].should eq(user.email)
    end
  end

  it "does not reset an invalid user" do
    patch "/api/users/wrongToken/reset", {}, {"Api-Token" => @account.token}

    response.status.should eq(404)

    r = JSON.parse(response.body)
    r["error"].should eq("404 Not Found")
  end

  it "generates recovery codes" do
    user_field_change(@user, :recovery_codes, true) do
      post "/api/users/#{@user.token}/recovery_codes", {}, {"Api-Token" => @account.token}

      response.status.should eq(201)

      r = JSON.parse(response.body)
      r["ok"].should eq(1)
      r["recovery_codes"].length.should eq(10)
    end
  end

  it "displays recovery codes" do
    @user.generate_recovery_codes
    user_field_change(@user, :recovery_codes, false) do
      get "/api/users/#{@user.token}/recovery_codes", {}, {"Api-Token" => @account.token}

      response.status.should eq(200)

      r = JSON.parse(response.body)
      r["ok"].should eq(1)
      r["recovery_codes"].length.should eq(10)
    end
  end

  it "validates recovery code" do
    @user.update_attributes(recovery_codes: ["0000011111"])
    user_field_change(@user, :recovery_codes, true) do
      get "/api/users/#{@user.token}/recovery_codes/00000-11111", {}, {"Api-Token" => @account.token}

      response.status.should eq(200)

      r = JSON.parse(response.body)
      r["ok"].should eq(1)
    end
  end

  it "doesn't validate invalid recovery code" do
    @user.update_attributes(recovery_codes: ["0000022222"])
    user_field_change(@user, :recovery_codes, false) do
      get "/api/users/#{@user.token}/recovery_codes/00000-11111", {}, {"Api-Token" => @account.token}

      response.status.should eq(403)

      r = JSON.parse(response.body)
      r["error"].should_not eq(nil)
    end
  end

  def user_field_change(user, field, should_change, &block)
    previous_value = user.send(field)
    block.call
    user.reload
    if should_change
      user.send(field).should_not eq(previous_value)
    else
      user.send(field).should eq(previous_value)
    end
  end

  def user_count_changes_by(int, &block)
    user_count = User.count
    block.call
    User.count.should eq(user_count + int)
  end
end
