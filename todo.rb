require 'json'

TASKS_FILE = 'tasks.json'

class Task
  attr_accessor :description, :completed, :subtasks

  def initialize(description)
    @description = description
    @completed = false
    @subtasks = []
  end

  def to_h
    {
      description: @description,
      completed: @completed,
      subtasks: @subtasks.map(&:to_h)
    }
  end

  def self.from_h(hash)
    task = new(hash['description'])
    task.completed = hash['completed']
    task.subtasks = hash['subtasks'].map { |subtask| Task.from_h(subtask) }
    task
  end
end

class TodoApp
  def initialize
    @tasks = []
    load_tasks
  end

  def start
    puts 'Welcome to the To-Do App!'
    puts 'Type ? for help or q to quit.'
    puts
    list_tasks
    puts
    prompt_user
  end

  def prompt_user
    loop do
      print '> '
      input = gets.chomp
      puts
      break if handle_input(input) == :quit
      puts
    end
  end

  def handle_input(input)
    command, *args = input.split(' ')

    case command
    when 'a' then add_task(args.join(' '))
    when 's' then add_subtask(args[0], args[1..-1].join(' '))
    when 't' then list_tasks
    when 'x' then toggle_complete(args[0])
    when 'd' then remove_task(args[0])
    when 'h' then move_task_up(args[0])
    when 'l' then move_task_down(args[0])
    when 'r' then rename_task(args[0], args[1..-1].join(' '))
    when '?' then show_help
    when 'q' then return :quit
    else puts 'Invalid command. Type ? for help.'
    end

    list_tasks unless ['t', '?'].include?(command)
    save_tasks
    nil
  end

  def add_task(description)
    @tasks << Task.new(description)
    puts 'Task added successfully.'
  end

  def add_subtask(task_index, description)
    index = task_index.to_i - 1
    if valid_index?(index)
      @tasks[index].subtasks << Task.new(description)
      puts 'Subtask added successfully.'
    else
      puts 'Invalid task number.'
    end
  end

  def list_tasks
    if @tasks.empty?
      puts 'No tasks.'
      return
    end

    puts 'Current tasks:'
    puts
    @tasks.each_with_index do |task, index|
      puts "#{index + 1}. [#{task.completed ? 'X' : ' '}] #{task.description}"
      task.subtasks.each_with_index do |subtask, subindex|
        puts "   #{index + 1}.#{subindex + 1}. [#{subtask.completed ? 'X' : ' '}] #{subtask.description}"
      end
    end
  end

  def toggle_complete(identifier)
    task_index, subtask_index = parse_identifier(identifier)
    if valid_index?(task_index)
      if subtask_index
        if valid_subtask_index?(task_index, subtask_index)
          @tasks[task_index].subtasks[subtask_index].completed = !@tasks[task_index].subtasks[subtask_index].completed
          puts 'Subtask status toggled.'
        else
          puts 'Invalid subtask number.'
        end
      else
        @tasks[task_index].completed = !@tasks[task_index].completed
        puts 'Task status toggled.'
      end
    else
      puts 'Invalid task number.'
    end
  end

  def remove_task(identifier)
    task_index, subtask_index = parse_identifier(identifier)
    if valid_index?(task_index)
      if subtask_index
        if valid_subtask_index?(task_index, subtask_index)
          @tasks[task_index].subtasks.delete_at(subtask_index)
          puts 'Subtask removed successfully.'
        else
          puts 'Invalid subtask number.'
        end
      else
        @tasks.delete_at(task_index)
        puts 'Task removed successfully.'
      end
    else
      puts 'Invalid task number.'
    end
  end

  def move_task_up(identifier)
    task_index, subtask_index = parse_identifier(identifier)
    if valid_index?(task_index)
      if subtask_index
        if valid_subtask_index?(task_index, subtask_index) && subtask_index > 0
          swap_array_elements(@tasks[task_index].subtasks, subtask_index, subtask_index - 1)
          puts 'Subtask moved up.'
        else
          puts 'Cannot move subtask up.'
        end
      elsif task_index > 0
        swap_array_elements(@tasks, task_index, task_index - 1)
        puts 'Task moved up.'
      else
        puts 'Cannot move task up.'
      end
    else
      puts 'Invalid task number.'
    end
  end

  def move_task_down(identifier)
    task_index, subtask_index = parse_identifier(identifier)
    if valid_index?(task_index)
      if subtask_index
        if valid_subtask_index?(task_index, subtask_index) && subtask_index < @tasks[task_index].subtasks.length - 1
          swap_array_elements(@tasks[task_index].subtasks, subtask_index, subtask_index + 1)
          puts 'Subtask moved down.'
        else
          puts 'Cannot move subtask down.'
        end
      elsif task_index < @tasks.length - 1
        swap_array_elements(@tasks, task_index, task_index + 1)
        puts 'Task moved down.'
      else
        puts 'Cannot move task down.'
      end
    else
      puts 'Invalid task number.'
    end
  end

  def rename_task(identifier, new_description)
    task_index, subtask_index = parse_identifier(identifier)
    if valid_index?(task_index)
      if subtask_index
        if valid_subtask_index?(task_index, subtask_index)
          @tasks[task_index].subtasks[subtask_index].description = new_description
          puts 'Subtask renamed successfully.'
        else
          puts 'Invalid subtask number.'
        end
      else
        @tasks[task_index].description = new_description
        puts 'Task renamed successfully.'
      end
    else
      puts 'Invalid task number.'
    end
  end

  def show_help
    puts 'Available commands:'
    puts 'a <task description> - Add a new task'
    puts 's <task number> <subtask description> - Add a subtask to a task'
    puts 't - List all tasks'
    puts 'x <task number>[.<subtask number>] - Mark task or subtask as complete/incomplete'
    puts 'd <task number>[.<subtask number>] - Remove task or subtask'
    puts 'h <task number>[.<subtask number>] - Move task or subtask higher'
    puts 'l <task number>[.<subtask number>] - Move task or subtask lower'
    puts 'r <task number>[.<subtask number>] <new description> - Rename task or subtask'
    puts '? - Show this help message'
    puts 'q - Quit the application'
  end

  private

  def load_tasks
    if File.exist?(TASKS_FILE)
      json = File.read(TASKS_FILE)
      @tasks = JSON.parse(json).map { |task_hash| Task.from_h(task_hash) }
    else
      @tasks = []
    end
  rescue JSON::ParserError
    @tasks = []
  end

  def save_tasks
    File.write(TASKS_FILE, JSON.pretty_generate(@tasks.map(&:to_h)))
  end

  def valid_index?(index)
    index >= 0 && index < @tasks.length
  end

  def valid_subtask_index?(task_index, subtask_index)
    subtask_index >= 0 && subtask_index < @tasks[task_index].subtasks.length
  end

  def parse_identifier(identifier)
    task_str, subtask_str = identifier.split('.')
    task_index = task_str.to_i - 1
    subtask_index = subtask_str ? subtask_str.to_i - 1 : nil
    [task_index, subtask_index]
  end

  def swap_array_elements(array, index1, index2)
    array[index1], array[index2] = array[index2], array[index1]
  end
end

app = TodoApp.new
app.start
