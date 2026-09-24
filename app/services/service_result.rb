# Outcome of a service call. Expected business failures (expired coupon, nothing
# left to generate...) are returned as an error code instead of raised, so callers
# branch on `success?` and map `error` to a message or HTTP status.
ServiceResult = Data.define(:value, :error) do
  def self.success(value = nil) = new(value:, error: nil)
  def self.failure(error) = new(value: nil, error:)

  def success? = error.nil?
  def failure? = !success?
end
