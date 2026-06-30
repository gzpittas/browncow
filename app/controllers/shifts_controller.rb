class ShiftsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_location
  before_action :set_schedule
  before_action :ensure_schedule_editable!
  before_action :set_shift, only: [ :edit, :update, :destroy, :move, :copy ]
  before_action :set_form_context, only: [ :new, :create ]
  before_action :set_form_context_from_shift, only: [ :edit, :update ]

  def new
    @shift = @schedule.shifts.build(
      employee: @selected_employee,
      position: @selected_position,
      shift_date: params[:shift_date].presence || @schedule.week_start_date
    )
  end

  def create
    @shift = @schedule.shifts.build(shift_params)

    if @shift.save
      redirect_to schedule_return_path, notice: "Shift saved."
    else
      set_form_context_from_shift
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shift.update(shift_params)
      redirect_to schedule_return_path, notice: "Shift updated."
    else
      set_form_context_from_shift
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to location_schedule_path(@location, @schedule, view: params[:view].presence || "positions", section: params[:section].presence || @section_mode), notice: "Shift deleted."
  end

  def move
    original_date = @shift.shift_date
    original_position = @shift.position

    if @shift.update(quick_edit_shift_params)
      respond_to_quick_edit_success(move_shift_message(@shift, original_date:, original_position:), shift: @shift, action: "move")
    else
      @shift.shift_date = original_date
      @shift.position = original_position
      respond_to_quick_edit_failure(@shift.errors.full_messages.to_sentence)
    end
  end

  def copy
    destination_date = quick_edit_shift_date

    if destination_date.blank?
      return respond_to_quick_edit_failure("Choose a day inside this schedule week.")
    end

    if destination_date == @shift.shift_date
      return respond_to_quick_edit_failure("Choose a different day for the copied shift.")
    end

    copied_shift = @schedule.shifts.build(
      employee: @shift.employee,
      position: quick_edit_position || @shift.position,
      shift_date: destination_date,
      starts_at: @shift.starts_at,
      ends_at: @shift.ends_at,
      notes: @shift.notes
    )

    if copied_shift.save
      respond_to_quick_edit_success("Shift copied to #{shift_date_message(copied_shift.shift_date)}.", shift: copied_shift, action: "copy")
    else
      respond_to_quick_edit_failure(copied_shift.errors.full_messages.to_sentence)
    end
  end

  private

  def set_location
    @location = current_user.account.locations.find(params[:location_id])
  end

  def set_schedule
    @schedule = @location.schedules.find(params[:schedule_id])
  end

  def ensure_schedule_editable!
    return if @schedule.editable?

    message = "Unpublish this schedule before making changes."

    respond_to do |format|
      format.html { redirect_to schedule_return_path, alert: message }
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def set_shift
    @shift = @schedule.shifts.find(params[:id])
  end

  def set_form_context
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode])
    @selected_employee = @location.employees.find_by(id: params[:employee_id])
    @selected_position = selected_position_for_section
    @employees = employee_scope_for_section.distinct.order(:first_name, :last_name)
    @positions = position_scope_for_section.ordered

    if @selected_employee
      @positions = scoped_employee_positions.ordered
    elsif @selected_position
      @employees = @selected_position.employees.active.order(:first_name, :last_name)
    end
  end

  def set_form_context_from_shift
    @section_mode = store_schedule_section_mode!(params[:section].presence || session[:schedule_section_mode] || @shift.position.section)
    @selected_employee = @shift.employee
    @selected_position = @shift.position if params[:position_id].present?
    @employees = @selected_position ? @selected_position.employees.active.order(:first_name, :last_name) : employee_scope_for_section.distinct.order(:first_name, :last_name)
    @positions = @selected_employee ? employee_positions_for_form(@selected_employee, include_position: @shift.position).ordered : position_scope_for_section.ordered
  end

  def shift_params
    params.require(:shift).permit(:employee_id, :position_id, :shift_date, :starts_at, :ends_at, :notes)
  end

  def quick_edit_shift_params
    params.require(:shift).permit(:shift_date, :position_id)
  end

  def quick_edit_shift_date
    value = quick_edit_shift_params[:shift_date]
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end

  def quick_edit_position
    position_id = quick_edit_shift_params[:position_id].presence
    return if position_id.blank?

    @location.positions.find_by(id: position_id)
  end

  def schedule_return_path
    view = normalized_schedule_view_mode(params[:view])
    section = params[:section].presence || (defined?(@section_mode) && @section_mode) || current_schedule_section_mode
    location_schedule_path(@location, @schedule, view: view, section: section)
  end

  def respond_to_quick_edit_success(message, shift:, action:)
    respond_to do |format|
      format.json do
        render json: {
          message: message,
          action: action,
          shift_id: shift.id,
          shift_date: shift.shift_date.iso8601,
          shift_html: rendered_shift_pill(shift),
          redirect_url: schedule_return_path
        }
      end
      format.html { redirect_to schedule_return_path, notice: message }
    end
  end

  def respond_to_quick_edit_failure(message)
    message = "Shift could not be updated." if message.blank?

    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_to schedule_return_path, alert: message }
    end
  end

  def shift_date_message(date)
    date.strftime("%A")
  end

  def move_shift_message(shift, original_date:, original_position:)
    date_changed = shift.shift_date != original_date
    position_changed = shift.position_id != original_position.id

    if date_changed && position_changed
      "Shift moved to #{shift.position.name} on #{shift_date_message(shift.shift_date)}."
    elsif position_changed
      "Shift moved to #{shift.position.name}."
    else
      "Shift moved to #{shift_date_message(shift.shift_date)}."
    end
  end

  def rendered_shift_pill(shift)
    @section_mode = params[:section].presence || current_schedule_section_mode

    render_to_string(
      partial: "schedules/shift_pill",
      formats: [ :html ],
      locals: shift_pill_locals(shift)
    )
  end

  def shift_pill_locals(shift)
    view_mode = normalized_schedule_view_mode(params[:view])
    locals = {
      shift: shift,
      title: shift.employee.display_name,
      view_mode: view_mode
    }

    if view_mode == "employees"
      locals.merge(secondary_text: shift.position.name, tertiary_text: helpers.shift_time_range(shift))
    else
      locals.merge(secondary_text: helpers.shift_time_range(shift))
    end
  end

  def selected_position_for_section
    position = @location.positions.find_by(id: params[:position_id])
    return unless position
    return position if @section_mode == "all" || position.section == @section_mode

    nil
  end

  def employee_scope_for_section
    scope = @location.employees.active.joins(:positions)
    return scope if @section_mode == "all"

    scope.where(positions: { section: @section_mode })
  end

  def position_scope_for_section
    scope = @location.positions.active
    return scope if @section_mode == "all"

    scope.where(section: @section_mode)
  end

  def scoped_employee_positions
    scope = @selected_employee.positions.active
    return scope if @section_mode == "all"

    scope.where(section: @section_mode)
  end

  def employee_positions_for_form(employee, include_position: nil)
    position_ids = employee.positions.active.ids
    position_ids << include_position.id if include_position.present?

    position_scope_for_section.where(id: position_ids.uniq)
  end
end
