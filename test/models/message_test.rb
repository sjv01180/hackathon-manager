require 'test_helper'

class MessageTest < ActiveSupport::TestCase
  should strip_attribute :type
  should strip_attribute :name
  should strip_attribute :subject
  should strip_attribute :template
  should strip_attribute :body
  should strip_attribute :trigger

  should validate_presence_of :name
  should validate_presence_of :subject
  should validate_presence_of :template
  should validate_presence_of :body
  should_not validate_presence_of :recipients
  should_not validate_presence_of :trigger

  should allow_value("default").for(:template)
  should_not allow_value("foo").for(:template)

  should allow_value("bulk").for(:type)
  should allow_value("automated").for(:type)
  should_not allow_value("foo").for(:type)

  should "validate body template parsing" do
    message = build(:message, body: "this body has invalid syntax {{foo")
    assert_equal false, message.valid?
    assert_match /failed to parse/, message.errors[:body][0]
  end

  should "allow valid body template variables" do
    message = build(:message, body: "this body has invalid syntax {{foo_bar}}")
    assert_equal true, message.valid?
  end

  context "parsed_body" do
    should "parse template variables with examples" do
      message = build(:message, body: "Hello, {{first_name}}!")
      assert_equal "Hello, John!", message.parsed_body({}, true)
    end

    should "parse template variables with real values" do
      questionnaire = create(:questionnaire, first_name: 'Richard')
      message = build(:message, body: "Hello, {{first_name}}!")
      assert_equal "Hello, Richard!", message.parsed_body(user_id: questionnaire.user_id)
    end

    should "ignore unknown variables" do
      message = build(:message, body: "Hello {{foo}} World")
      assert_equal "Hello  World", message.parsed_body({})
    end
  end

  context "bulk?" do
    should "return true for a bulk email" do
      message = build(:message, type: "bulk")
      assert_equal true, message.bulk?
    end

    should "return false for an automated email" do
      message = build(:message, type: "automated")
      assert_equal false, message.bulk?
    end
  end

  context "automated?" do
    should "return false for a bulk email" do
      message = build(:message, type: "bulk")
      assert_equal false, message.automated?
    end

    should "return true for an automated email" do
      message = build(:message, type: "automated")
      assert_equal true, message.automated?
    end
  end

  context "recipients_list" do
    should "return human-readable list of basic recipients" do
      message = build(:message, recipients: ['all', 'incomplete'])
      assert_equal ["Everyone", "Incomplete Applications"], message.recipients_list
    end

    should "return human-readable list of querying recipients" do
      create(:school, id: 567, name: 'My School')
      message = build(:message, recipients: ['accepted', 'school::567'])
      assert_equal ["Accepted Applications", "Confirmed or Accepted: My School"], message.recipients_list
    end

    should "return unknown for invalid recipients" do
      message = build(:message, recipients: ['all', 'foo', 'incomplete'])
      assert_equal ["Everyone", "(unknown)", "Incomplete Applications"], message.recipients_list
    end
  end

  context "delivered?" do
    should "return false if delivered date is not set" do
      message = build(:message)
      assert_equal false, message.delivered?
    end

    should "return true if delivered date is set" do
      message = build(:message, queued_at: 1.hour.ago, delivered_at: 1.hour.ago)
      assert_equal true, message.delivered?
    end
  end

  context "started?" do
    should "return false if started date is not set" do
      message = build(:message)
      assert_equal false, message.started?
    end

    should "return true if started date is set" do
      message = build(:message, started_at: 1.hour.ago)
      assert_equal true, message.started?
    end
  end

  context "queued?" do
    should "return false if queued date is not set" do
      message = build(:message)
      assert_equal false, message.queued?
    end

    should "return true if queued date is set" do
      message = build(:message, queued_at: 1.hour.ago)
      assert_equal true, message.queued?
    end
  end

  context "status" do
    should "return drafted if not queued or delivered" do
      message = build(:message)
      assert_equal "drafted", message.status
    end

    should "return queued if not queued or delivered" do
      message = build(:message, queued_at: 1.hour.ago)
      assert_equal "queued", message.status
    end

    should "return started if started but not delivered" do
      message = build(:message, queued_at: 1.hour.ago, started_at: 1.hour.ago)
      assert_equal "started", message.status
    end

    should "return delivered if not queued or delivered" do
      message = build(:message, queued_at: 1.hour.ago, started_at: 1.hour.ago, delivered_at: 1.hour.ago)
      assert_equal "delivered", message.status
    end

    should "return automated if automated type" do
      message = build(:message, type: 'automated', queued_at: 1.hour.ago, started_at: 1.hour.ago, delivered_at: 1.hour.ago)
      assert_equal "automated", message.status
    end
  end

  context "can_edit?" do
    should "return true if message has not been queued, started, or delivered" do
      message = build(:message)
      assert_equal true, message.can_edit?
    end

    should "return false if message has been queued, started, or delivered" do
      message = build(:message, queued_at: 1.hour.ago)
      assert_equal false, message.can_edit?
      message = build(:message, queued_at: 1.hour.ago, started_at: 1.hour.ago)
      assert_equal false, message.can_edit?
      message = build(:message, queued_at: 1.hour.ago, started_at: 1.hour.ago, delivered_at: 1.hour.ago)
      assert_equal false, message.can_edit?
    end

    should "return true if message has been delivered but has a trigger" do
      message = build(:message, queued_at: 1.hour.ago, started_at: 1.hour.ago, delivered_at: 1.hour.ago)
      assert_equal false, message.can_edit?
    end
  end

  context "using_default_template?" do
    should "return true if message template is default" do
      message = build(:message)
      assert message.using_default_template?
    end

    should "return false if message template is not default" do
      message = build(:message, template: "accepted")
      assert !message.using_default_template?
    end
  end

  context "for_trigger" do
    should "return automated messages matching a given trigger" do
      create(:message, trigger: "questionnaire.pending", subject: "Pending 1")
      create(:message, trigger: "questionnaire.pending", subject: "Pending 2")
      create(:message, trigger: "questionnaire.accepted", subject: "Accepted")
      assert_equal 2, Message.for_trigger("questionnaire.pending").count
      assert_equal 1, Message.for_trigger("questionnaire.accepted").count
      assert_equal 0, Message.for_trigger("questionnaire.denied").count
    end

    should "raise exception for unknown triggers" do
      assert_raise ArgumentError, "Unknowna trigger: foo" do
        Message.for_trigger("foo")
      end
    end
  end
end
