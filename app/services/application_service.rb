# Base class for service objects: `SomeService.call(**args)` builds the service
# and runs it, so callers never hold on to half-configured instances.
class ApplicationService
  def self.call(...)
    new(...).call
  end

  private

  def success(value = nil)
    ServiceResult.success(value)
  end

  def failure(error)
    ServiceResult.failure(error)
  end
end
